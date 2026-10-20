require "test_helper"

class ChatCompletionServiceTest < ActiveSupport::TestCase
  class FakeLLMChat
    attr_reader :messages, :asked

    def initialize(reply = "Answer\n[SOURCES: none]")
      @messages = []
      @reply = reply
    end

    def with_instructions(_text) = self

    def add_message(role:, content:)
      @messages << [ role, content ]
    end

    def ask(content)
      @asked = content
      Struct.new(:content).new(@reply)
    end
  end

  setup do
    @note = notes(:one)
    @chat = users(:one).chats.create!(title: "Chat", source_note_ids: [ @note.id ])
    @chat.messages.create!(role: "user", content: "Earlier question")
    @chat.messages.create!(role: "assistant", content: "Earlier answer")
    @llm = FakeLLMChat.new
    @searched_filters = []
  end

  def run_service(chat = @chat, query = "Current question")
    filters = @searched_filters
    search = ->(_text, top_k:, filter:) { filters << filter; { "result" => { "hits" => [] } } }
    llm = @llm
    with_stub(PineconeHelper, :search, search) do
      with_stub(RubyLLM, :chat, ->(**) { llm }) do
        ChatCompletionService.new(chat, query).call
      end
    end
  end

  test "prompt holds prior history and the current query exactly once" do
    run_service

    assert_equal [ [ :user, "Earlier question" ], [ :assistant, "Earlier answer" ] ], @llm.messages
    assert_equal "Current question", @llm.asked
    assert_equal %w[user assistant user assistant], @chat.messages.order(:created_at).pluck(:role)
  end

  test "search ignores notes deleted from the chat's sources" do
    gone = notes(:uncategorized)
    @chat.update_columns(source_note_ids: [ @note.id, gone.id ])
    Note.where(id: gone.id).delete_all

    run_service

    assert_equal [ @note.id ], @searched_filters.first.dig("note_id", "$in")
  end

  test "persists the full chunk body without the indexing prefix as the source chunk_text" do
    body = "Paragraph about planning. " * 60
    hit = { "fields" => { "note_id" => @note.id, "title" => "T", "text" => "title: T\ntags: a, b\n\n#{body}" } }
    search = ->(_text, top_k:, filter:) { { "result" => { "hits" => [ hit ] } } }
    llm = FakeLLMChat.new("Answer\n[SOURCES: #{@note.id}]")

    message = with_stub(PineconeHelper, :search, search) do
      with_stub(RubyLLM, :chat, ->(**) { llm }) do
        ChatCompletionService.new(@chat, "Current question").call
      end
    end

    chunk_text = message.reload.sources.first["chunk_text"]
    assert_operator body.length, :>, 1000
    assert_equal body, chunk_text
    assert_no_match(/\.\.\.\z/, chunk_text)
  end

  test "caps an oversized chunk body at 4000 characters with no omission marker" do
    body = "x" * 9_000
    hit = { "fields" => { "note_id" => @note.id, "title" => "T", "text" => "title: T\ntags: a\n\n#{body}" } }
    search = ->(_text, top_k:, filter:) { { "result" => { "hits" => [ hit ] } } }
    llm = FakeLLMChat.new("Answer\n[SOURCES: #{@note.id}]")

    message = with_stub(PineconeHelper, :search, search) do
      with_stub(RubyLLM, :chat, ->(**) { llm }) do
        ChatCompletionService.new(@chat, "Current question").call
      end
    end

    chunk_text = message.reload.sources.first["chunk_text"]
    assert_equal 4_000, chunk_text.length
    assert_equal body.first(4_000), chunk_text
  end

  test "raises when every selected note is gone" do
    @chat.update_columns(source_note_ids: [ 0 ])

    assert_raises(RuntimeError) { run_service }
  end
end
