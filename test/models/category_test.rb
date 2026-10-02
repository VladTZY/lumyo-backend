require "test_helper"

class CategoryTest < ActiveSupport::TestCase
  setup do
    @category = categories(:one)
    @note = notes(:one)
  end

  test "renaming reindexes the category's notes" do
    assert_enqueued_with(job: EmbedNoteJob, args: [ @note.id ]) do
      @category.update!(title: "Renamed")
    end
  end

  test "saving without a title change does not reindex" do
    assert_no_enqueued_jobs only: EmbedNoteJob do
      @category.touch
    end
  end

  test "destroying reindexes the notes that carried it" do
    assert_enqueued_with(job: EmbedNoteJob, args: [ @note.id ]) do
      @category.destroy!
    end
  end
end
