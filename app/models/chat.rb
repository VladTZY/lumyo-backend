class Chat < ApplicationRecord
  belongs_to :user
  has_many :messages, dependent: :destroy

  validates :title, presence: true
  validate :source_notes_belong_to_user, if: :source_note_ids_changed?

  before_validation :normalize_source_note_ids, if: :source_note_ids_changed?

  # Drops a deleted note from every chat of its owner that still selects it.
  def self.remove_source_note_id(user_id, note_id)
    where(user_id: user_id).find_each do |chat|
      remaining = chat.source_note_ids.reject { |id| id.to_i == note_id }
      chat.update_columns(source_note_ids: remaining) if remaining.size != chat.source_note_ids.size
    end
  end

  # Selected note ids that still exist and belong to the chat's owner.
  def available_source_note_ids
    return [] if source_note_ids.blank?

    user.notes.where(id: source_note_ids.map(&:to_i)).pluck(:id)
  end

  private

  def normalize_source_note_ids
    self.source_note_ids = Array(source_note_ids).map(&:to_i).uniq
  end

  def source_notes_belong_to_user
    return if source_note_ids.empty?
    return if user && user.notes.where(id: source_note_ids).count == source_note_ids.size

    errors.add(:source_note_ids, "must reference your own existing notes")
  end
end
