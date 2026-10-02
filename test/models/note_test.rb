require "test_helper"

class NoteTest < ActiveSupport::TestCase
  setup do
    @note = notes(:uncategorized)
    @category = categories(:one)
  end

  test "adding a category reindexes the note" do
    assert_enqueued_with(job: EmbedNoteJob, args: [ @note.id ]) do
      @note.categories << @category
    end
  end

  test "replacing categories reindexes the note" do
    note = notes(:one)
    other = note.user.categories.create!(title: "Other")

    assert_enqueued_jobs 2, only: EmbedNoteJob do
      note.categories = [ other ]
    end
  end

  test "removing a category reindexes the note" do
    note = notes(:one)

    assert_enqueued_with(job: EmbedNoteJob, args: [ note.id ]) do
      note.categories.delete(categories(:one))
    end
  end

  test "category change on an unsaved note does not enqueue" do
    note = users(:one).notes.build(title: "Draft", content: "Body")

    assert_no_enqueued_jobs only: EmbedNoteJob do
      note.categories << @category
    end
  end

  test "destroying a note removes its vectors" do
    assert_enqueued_with(job: RemoveNoteFromIndexJob, args: [ @note.id ]) do
      @note.destroy!
    end
  end

  test "destroying a note drops it from its owner's chats" do
    keep = notes(:one)
    chat = users(:one).chats.create!(title: "Chat", source_note_ids: [ @note.id, keep.id ])
    string_chat = users(:one).chats.create!(title: "Chat", source_note_ids: [ @note.id.to_s ])

    @note.destroy!

    assert_equal [ keep.id ], chat.reload.source_note_ids
    assert_equal [], string_chat.reload.source_note_ids
  end
end
