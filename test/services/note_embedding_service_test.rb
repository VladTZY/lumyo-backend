require "test_helper"

class NoteEmbeddingServiceTest < ActiveSupport::TestCase
  setup do
    @note = notes(:one)
    @deleted = []
    @upserted = []
  end

  def run_service
    deleted, upserted = @deleted, @upserted
    with_stub(PineconeHelper, :delete_by_filter, ->(filter) { deleted << filter }) do
      with_stub(PineconeHelper, :upsert_records, ->(records) { upserted.concat(records) }) do
        NoteEmbeddingService.new(@note).call
      end
    end
  end

  test "upserts chunks with current category titles" do
    run_service

    assert_equal [ categories(:one).title ], @upserted.first["tags"]
    assert @note.reload.pinecone_uploaded
  end

  test "cleans up vectors when the note was deleted mid-run" do
    @note = notes(:uncategorized)
    Note.where(id: @note.id).delete_all

    run_service

    assert_equal 2, @deleted.size
    assert_equal({ "note_id" => @note.id }, @deleted.last)
  end
end
