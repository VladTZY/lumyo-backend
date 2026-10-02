require "test_helper"

class ChatTest < ActiveSupport::TestCase
  test "available_source_note_ids skips deleted and foreign notes" do
    own = notes(:one)
    chat = users(:one).chats.create!(title: "Chat")
    chat.update_columns(source_note_ids: [ own.id.to_s, notes(:two).id, 0 ])

    assert_equal [ own.id ], chat.available_source_note_ids
  end

  test "normalizes source note ids to unique integers" do
    id = notes(:one).id
    chat = users(:one).chats.create!(title: "Chat", source_note_ids: [ id.to_s, id ])

    assert_equal [ id ], chat.source_note_ids
  end

  test "rejects notes owned by another user" do
    chat = users(:one).chats.build(title: "Chat", source_note_ids: [ notes(:one).id, notes(:two).id ])

    assert_not chat.valid?
    assert chat.errors[:source_note_ids].any?
  end

  test "rejects notes that do not exist" do
    chat = users(:one).chats.build(title: "Chat", source_note_ids: [ 0 ])

    assert_not chat.valid?
  end

  test "does not revalidate untouched source ids" do
    chat = users(:one).chats.create!(title: "Chat")
    chat.update_columns(source_note_ids: [ 0 ])

    assert chat.update(title: "Renamed")
  end
end
