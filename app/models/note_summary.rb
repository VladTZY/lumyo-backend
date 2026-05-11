class NoteSummary < ApplicationRecord
  belongs_to :note

  enum :status, {
    pending: "pending",
    generating: "generating",
    completed: "completed",
    failed: "failed"
  }

  validates :status, presence: true
end
