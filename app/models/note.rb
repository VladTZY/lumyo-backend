class Note < ApplicationRecord
  belongs_to :user

  has_many :note_categories, dependent: :destroy
  has_many :categories, through: :note_categories
  has_one :note_summary, dependent: :destroy

  validates :title, presence: true
  validates :content, presence: true
end
