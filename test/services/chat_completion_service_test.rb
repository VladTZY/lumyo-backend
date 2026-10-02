require "test_helper"

class ChatCompletionServiceTest < ActiveSupport::TestCase
  class FakeLLMChat
    attr_reader :messages, :asked

    def initialize
      @messages = []
    end

    def with_instructions(_text) = self

    def add_message(role:, content:)
      @messages << [ role, content ]
    end

    def ask(content)
      @asked = content
      Struct.new(:content).new("Answer\n[SOURCES: none]")
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
    gone.delete

    run_service

    assert_equal [ @note.id ], @searched_filters.first.dig("note_id", "$in")
  end

  test "raises when every selected note is gone" do
    @chat.update_columns(source_note_ids: [ 0 ])

    assert_raises(RuntimeError) { run_service }
  end
end
