require "test_helper"

class ChatTest < ActiveSupport::TestCase
  test "available_source_note_ids skips deleted and foreign notes" do
    own = notes(:one)
    foreign = notes(:two)
    chat = users(:one).chats.create!(title: "Chat", source_note_ids: [ own.id.to_s, foreign.id, 0 ])

    assert_equal [ own.id ], chat.available_source_note_ids
  end
end
