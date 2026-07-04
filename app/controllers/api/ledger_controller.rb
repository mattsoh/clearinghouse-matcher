class Api::LedgerController < ApplicationController
  include OrganizationScoped

  # running_balance here is cumulative only within the cached window, not the
  # true HCB account balance (that would need full account history, which
  # would blow the shared rate limit) -- a deliberate, flagged deviation from
  # the old CSV-derived ledger, which had the same caveat (labeled "(CSV)").
  def index
    transactions = Hcb::OrganizationTransactions.new(hcb_client, organization_id).all
    sorted = transactions.sort_by { |t| [ t["date"].to_s, t["id"].to_s ] }

    running = 0.0
    rows = sorted.map do |t|
      presenter = Hcb::TransactionPresenter.new(t)
      running = (running + presenter.amount).round(2)
      presenter.as_json.merge(running_balance: running, is_zero_point: false)
    end

    render json: {
      zero_balance_date: nil,
      final_balance: rows.last&.fetch(:running_balance) || 0.0,
      ledger: rows
    }
  end

  # One HCB page at a time, so the frontend can render rows as they arrive
  # instead of blocking on the full drain #index needs for running balances.
  def page
    result = Hcb::OrganizationTransactions.new(hcb_client, organization_id)
      .fetch_page(stream_id: params[:stream_id].to_s, after: params[:after].presence)

    render json: {
      rows: result[:data].map { |t| Hcb::TransactionPresenter.new(t).as_json },
      has_more: result[:has_more],
      next_after: result[:next_after],
      total_count: result[:total_count]
    }
  end
end
