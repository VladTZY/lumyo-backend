require "test_helper"

class RemoveNoteFromIndexJobTest < ActiveSupport::TestCase
  test "deletes all vectors for the note" do
    deleted = []
    with_stub(PineconeHelper, :delete_by_filter, ->(filter) { deleted << filter }) do
      RemoveNoteFromIndexJob.perform_now(42)
    end

    assert_equal [ { "note_id" => 42 } ], deleted
  end
end
