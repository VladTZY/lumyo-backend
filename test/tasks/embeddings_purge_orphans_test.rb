require "test_helper"
require "rake"

class EmbeddingsPurgeOrphansTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    @task = Rake::Task["embeddings:purge_orphans"]
    @task.reenable
    live = notes(:one).id
    @ids = [ "note_#{live}_chunk_0", "note_0_chunk_0", "note_0_chunk_1" ]
  end

  def run_task(env = {})
    deleted = []
    ids = @ids
    with_stub(PineconeHelper, :each_id, ->(prefix:) { ids.each }) do
      with_stub(PineconeHelper, :delete_ids, ->(batch) { deleted.concat(batch) }) do
        env.each { |k, v| ENV[k] = v }
        capture_io { @task.invoke }
      ensure
        env.each_key { |k| ENV.delete(k) }
      end
    end
    deleted
  end

  test "deletes only vectors of notes that no longer exist" do
    assert_equal %w[note_0_chunk_0 note_0_chunk_1], run_task
  end

  test "dry run deletes nothing" do
    assert_empty run_task("DRY_RUN" => "1")
  end
end
