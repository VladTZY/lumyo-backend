class RemoveNoteFromIndexJob < ApplicationJob
  queue_as :default

  retry_on PineconeHelper::Error, wait: 5.seconds, attempts: 5
  retry_on KeyError, wait: 10.seconds, attempts: 2

  def perform(note_id)
    PineconeHelper.delete_by_filter({ "note_id" => note_id })
  rescue => e
    Rails.logger.error("[RemoveNoteFromIndexJob] Failed for note #{note_id}: #{e.class} - #{e.message}")
    raise
  end
end
