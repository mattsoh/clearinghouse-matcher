class Match < ApplicationRecord
  belongs_to :created_by, class_name: "User", foreign_key: :created_by_user_id, inverse_of: :created_matches
  belongs_to :undone_by, class_name: "User", foreign_key: :undone_by_user_id, inverse_of: :undone_matches, optional: true

  has_many :match_transactions, inverse_of: :match, dependent: :destroy
  has_many :adjustments, class_name: "MatchAdjustment", inverse_of: :match, dependent: :destroy

  validates :hcb_organization_id, presence: true

  scope :active, -> { where(undone_at: nil) }
  scope :for_organization, ->(org_id) { where(hcb_organization_id: org_id) }

  def undone? = undone_at.present?

  def incoming_transaction_ids
    match_transactions.active.incoming.pluck(:hcb_transaction_id)
  end

  def outgoing_transaction_ids
    match_transactions.active.outgoing.pluck(:hcb_transaction_id)
  end
end
