class EmbedNoteJob < ApplicationJob
  queue_as :default

  # Category changes enqueue from inside the association's transaction; the
  # job must not read the note before those changes are committed.
  self.enqueue_after_transaction_commit = true

  retry_on PineconeHelper::Error, wait: 5.seconds, attempts: 3
  retry_on KeyError, wait: 10.seconds, attempts: 2
  discard_on ActiveRecord::RecordNotFound

  def perform(note_id)
    note = Note.find(note_id)
    NoteEmbeddingService.new(note).call
  rescue => e
    Rails.logger.error("[EmbedNoteJob] Failed for note #{note_id}: #{e.class} - #{e.message}")
    raise
  end
end
