class MatchAdjustment < ApplicationRecord
  belongs_to :match, inverse_of: :adjustments
  belongs_to :created_by, class_name: "User", foreign_key: :created_by_user_id

  validates :amount_cents, presence: true
  validates :memo, presence: true
end
