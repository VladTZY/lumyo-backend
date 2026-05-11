class NoteCategory < ApplicationRecord
  belongs_to :note
  belongs_to :category

  validates :note_id, uniqueness: { scope: :category_id }
end
