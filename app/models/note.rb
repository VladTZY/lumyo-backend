class Note < ApplicationRecord
  belongs_to :user

  has_many :note_categories, dependent: :destroy
  has_many :categories, through: :note_categories
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
end
