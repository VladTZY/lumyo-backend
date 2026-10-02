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

  private

  def should_embed?
    saved_change_to_title? || saved_change_to_content?
  end

  def enqueue_embedding
    EmbedNoteJob.perform_later(id)
  end

  def enqueue_embedding_for_category_change(_category)
    enqueue_embedding if persisted?
  end
end
