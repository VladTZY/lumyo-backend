require "test_helper"

# Tester-added edge cases for NoteChunker.strip_prefix and ChatCompletionService#build_sources.
class SourceChunkEdgeTest < ActiveSupport::TestCase
  class RecordingLLM
    attr_reader :instructions

    def initialize(reply) = @reply = reply
    def with_instructions(text) = (@instructions = text; self)
    def add_message(role:, content:); end
    def ask(_content) = Struct.new(:content).new(@reply)
  end

  # strip_prefix

  test "strip_prefix returns empty string for prefix-only text" do
    assert_equal "", NoteChunker.strip_prefix("title: T\ntags: a\n\n")
  end

  test "strip_prefix removes only the leading prefix, not a later look-alike" do
    body = "intro\n\ntitle: X\ntags: y\n\nmore"
    assert_equal body, NoteChunker.strip_prefix(body)
    text = "title: T\ntags: a\n\ntitle: B\ntags: c\n\nrest"
    assert_equal "title: B\ntags: c\n\nrest", NoteChunker.strip_prefix(text)
  end

  test "strip_prefix keeps body markdown, unicode and whitespace unchanged" do
    body = "  **bold** \u{1F600} ünï\n\n\n• item  "
    assert_equal body, NoteChunker.strip_prefix("title: Tïtle \u{1F600}\ntags: a, b\n\n#{body}")
  end

  test "strip_prefix with empty title and many-line title" do
    assert_equal "b", NoteChunker.strip_prefix("title: \ntags: \n\nb")
    assert_equal "b", NoteChunker.strip_prefix("title: l1\nl2\n\nl3\ntags: z\n\nb")
  end

  test "strip_prefix returns empty string for empty string and tolerates non-strings" do
    assert_equal "", NoteChunker.strip_prefix("")
    assert_equal "12", NoteChunker.strip_prefix(12)
  end

  test "strip_prefix does not strip text with a single newline after tags" do
    text = "title: T\ntags: a\nbody"
    assert_equal text, NoteChunker.strip_prefix(text)
  end

  test "strip_prefix round-trips every chunk the chunker builds for a long note" do
    note = notes(:one)
    para = "Sentence number one is here. Sentence two follows it. " * 12
    note.update_columns(title: "Long\nmulti-line title", content: ([ para ] * 8).join("\n\n"))
    chunks = NoteChunker.new(note).chunks
    assert_operator chunks.size, :>, 1
    chunks.each do |c|
      stripped = NoteChunker.strip_prefix(c[:text])
      assert_not_empty stripped
      assert_no_match(/\Atitle: /, stripped)
      assert_includes c[:text], stripped
      assert c[:text].end_with?(stripped)
    end
  end

  # build_sources via ChatCompletionService#call

  def call_with_hits(hits, reply)
    search = ->(_t, top_k:, filter:) { { "result" => { "hits" => hits } } }
    llm = RecordingLLM.new(reply)
    chat = users(:one).chats.create!(title: "C", source_note_ids: [ notes(:one).id ])
    message = with_stub(PineconeHelper, :search, search) do
      with_stub(RubyLLM, :chat, ->(**) { llm }) { ChatCompletionService.new(chat, "q").call }
    end
    [ message.reload, llm ]
  end

  test "dedupes by note_id keeping the first (best ranked) chunk, each unprefixed and untruncated" do
    id = notes(:one).id
    long = "x" * 900
    hits = [
      { "fields" => { "note_id" => id, "title" => "T", "text" => "title: T\ntags: \n\n#{long}" } },
      { "fields" => { "note_id" => id, "title" => "T", "text" => "title: T\ntags: \n\nsecond" } }
    ]
    message, = call_with_hits(hits, "A\n[SOURCES: #{id}]")
    assert_equal 1, message.sources.size
    assert_equal long, message.sources.first["chunk_text"]
  end

  test "filters to the notes the model declared" do
    a = notes(:one).id
    b = notes(:uncategorized).id
    hits = [
      { "fields" => { "note_id" => a, "title" => "A", "text" => "title: A\ntags: \n\nalpha" } },
      { "fields" => { "note_id" => b, "title" => "B", "text" => "title: B\ntags: \n\nbeta" } }
    ]
    message, = call_with_hits(hits, "A\n[SOURCES: #{b}]")
    assert_equal [ b ], message.sources.map { |s| s["note_id"] }
    assert_equal "beta", message.sources.first["chunk_text"]
  end

  test "without a SOURCES marker every retrieved note is a source, with stripped chunk_text" do
    a = notes(:one).id
    hits = [ { "fields" => { "note_id" => a, "title" => "A", "text" => "title: A\ntags: x\n\nalpha" } } ]
    message, = call_with_hits(hits, "Answer without marker")
    assert_equal [ "alpha" ], message.sources.map { |s| s["chunk_text"] }
  end

  test "missing text field yields an empty chunk_text instead of raising" do
    a = notes(:one).id
    hits = [ { "fields" => { "note_id" => a, "title" => "A" } } ]
    message, = call_with_hits(hits, "A\n[SOURCES: #{a}]")
    assert_equal "", message.sources.first["chunk_text"]
  end

  test "the LLM context keeps the prefixed text" do
    a = notes(:one).id
    hits = [ { "fields" => { "note_id" => a, "title" => "A", "text" => "title: A\ntags: x\n\nalpha body" } } ]
    _, llm = call_with_hits(hits, "A\n[SOURCES: #{a}]")
    assert_includes llm.instructions, "title: A\ntags: x\n\nalpha body"
  end
end
