class Note < ApplicationRecord
  belongs_to :user

  has_many :note_categories, dependent: :destroy
  # Category titles are embedded in every chunk prefix, so adding or removing
  # a category must refresh the note's vectors.
  has_many :categories, through: :note_categories,
                        after_add: :enqueue_embedding_for_category_change,
                        after_remove: :enqueue_embedding_for_category_change
  has_one :note_summary, dependent: :destroy

  validates :title, presence: true
  validates :content, presence: true

  after_save_commit :enqueue_embedding, if: :should_embed?
  after_destroy_commit :remove_from_index

  private

  def should_embed?
    saved_change_to_title? || saved_change_to_content?
  end

  def enqueue_embedding
    EmbedNoteJob.perform_later(id)
  end

  # Replacing categories fires one callback per added/removed category; the
  # whole replacement runs in one transaction, so reindex once on commit.
  def enqueue_embedding_for_category_change(_category)
    return if !persisted? || @category_reindex_pending

    @category_reindex_pending = true
    transaction = self.class.current_transaction
    transaction.after_rollback { @category_reindex_pending = false }
    transaction.after_commit do
      @category_reindex_pending = false
      enqueue_embedding
    end
  end

  def remove_from_index
    RemoveNoteFromIndexJob.perform_later(id)
    Chat.remove_source_note_id(user_id, id)
  end
end
