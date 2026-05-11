class Category < ApplicationRecord
  belongs_to :user

  has_many :note_categories, dependent: :destroy
  has_many :notes, through: :note_categories

  validates :title, presence: true
end
