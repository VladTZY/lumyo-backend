class Category < ApplicationRecord
  belongs_to :user

  # Runs before dependent: :destroy wipes the join rows, so the notes that
  # carried this category are still known after the destroy commits.
  before_destroy :remember_note_ids, prepend: true

  has_many :note_categories, dependent: :destroy
  has_many :notes, through: :note_categories

  validates :title, presence: true

  # One callback for both events: Rails keeps only the last after_commit
  # registered for a given method name.
  after_commit :reindex_notes, on: [ :update, :destroy ], if: -> { destroyed? || saved_change_to_title? }

  private

  def remember_note_ids
    @note_ids_before_destroy = note_ids
  end

  # The category title is part of each note's indexed chunk prefix.
  def reindex_notes
    ids = @note_ids_before_destroy || note_ids
    ActiveJob.perform_all_later(ids.map { |id| EmbedNoteJob.new(id) }) if ids.any?
  end
end
