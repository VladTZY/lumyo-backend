require "test_helper"

# Tester-added boundary tests for the 4000-character source chunk cap (fix cycle 1).
class SourceChunkCapTest < ActiveSupport::TestCase
  class FakeLLM
    def initialize(reply) = @reply = reply
    def with_instructions(_text) = self
    def add_message(role:, content:); end
    def ask(_content) = Struct.new(:content).new(@reply)
  end

  setup do
    @note = notes(:one)
    @chat = users(:one).chats.create!(title: "Chat", source_note_ids: [ @note.id ])
  end

  def stored_chunk(body)
    hit = { "fields" => { "note_id" => @note.id, "title" => "T", "text" => "title: T\ntags: a\n\n#{body}" } }
    search = ->(_text, top_k:, filter:) { { "result" => { "hits" => [ hit ] } } }
    llm = FakeLLM.new("Answer\n[SOURCES: #{@note.id}]")
    message = with_stub(PineconeHelper, :search, search) do
      with_stub(RubyLLM, :chat, ->(**) { llm }) { ChatCompletionService.new(@chat, "q").call }
    end
    message.reload.sources.first["chunk_text"]
  end

  test "cap constant is 4000" do
    assert_equal 4_000, ChatCompletionService::MAX_SOURCE_CHUNK_CHARS
  end

  test "3999 characters are stored whole" do
    body = "a" * 3_999
    assert_equal body, stored_chunk(body)
  end

  test "exactly 4000 characters are stored whole" do
    body = "a" * 4_000
    assert_equal body, stored_chunk(body)
  end

  test "4001 characters are cut to the first 4000 with no marker" do
    body = ("a" * 4_000) + "Z"
    chunk = stored_chunk(body)
    assert_equal 4_000, chunk.length
    assert_equal "a" * 4_000, chunk
    assert_no_match(/\.\.\.|Z/, chunk)
  end

  test "multibyte text is capped by characters, not bytes" do
    body = "é" * 4_001
    chunk = stored_chunk(body)
    assert_equal 4_000, chunk.length
    assert_equal "é" * 4_000, chunk
    assert_equal 8_000, chunk.bytesize
  end

  test "emoji (4-byte, one codepoint each) are capped by codepoints and never split" do
    body = "\u{1F600}" * 4_050
    chunk = stored_chunk(body)
    assert_equal 4_000, chunk.length
    assert chunk.valid_encoding?
    assert_equal "\u{1F600}" * 4_000, chunk
  end

  test "the cap applies after the prefix is stripped, so the prefix does not eat the budget" do
    body = "b" * 4_000
    chunk = stored_chunk(body)
    assert_equal body, chunk
  end

  test "the capped chunk is a head slice of the body, so it still matches the note exactly" do
    body = (1..800).map { |i| "word#{i}" }.join(" ")
    chunk = stored_chunk(body)
    assert body.start_with?(chunk)
    assert_operator chunk.length, :<=, 4_000
  end
end
