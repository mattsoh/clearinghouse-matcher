class Api::TransactionsController < ApplicationController
  include OrganizationScoped

  # The old contract returned zero_balance_date/starting_balance/final_balance
  # alongside the flat transaction list; only zero_balance_date was ever read
  # by app.js, and the CSV-era zero-balance cutoff has no live-API equivalent
  # (see plan), so it's sent as null and app.js's existing `|| "n/a"` fallback
  # handles display without needing any frontend edit.
  def index
    render json: { zero_balance_date: nil, transactions: fetch_with_backfill.map { |t| Hcb::TransactionPresenter.new(t).as_json } }
  end

  private

  # allTransactions must include every transaction ever referenced by an
  # active match for this org, not just what's in the rolling cache window —
  # app.js looks up matched transactions by id (byId.get) when rendering the
  # confirmed-matches sections, and a match can easily outlive the window.
  def fetch_with_backfill
    all = Hcb::OrganizationTransactions.new(hcb_client, organization_id).all
    present_ids = all.map { |t| t["id"] }.to_set
    referenced_ids = MatchTransaction.active.where(hcb_organization_id: organization_id).pluck(:hcb_transaction_id)
    missing = referenced_ids.reject { |id| present_ids.include?(id) }
    all + missing.filter_map { |id| fetch_one(id) }
  end

  def fetch_one(id)
    Rails.cache.fetch("hcb:txn:#{id}:v1", expires_in: 1.day) { hcb_client.transaction(id) }
  rescue OAuth2::Error
    nil
  end
end
