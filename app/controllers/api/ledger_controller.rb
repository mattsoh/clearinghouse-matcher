class Api::LedgerController < ApplicationController
  include OrganizationScoped

  # running_balance here is cumulative only within the cached window, not the
  # true HCB account balance (that would need full account history, which
  # would blow the shared rate limit) -- a deliberate, flagged deviation from
  # the old CSV-derived ledger, which had the same caveat (labeled "(CSV)").
  #
  # The cutoff shown/settable here is the same organization-wide setting the
  # matcher uses (see Api::TransactionsController, OrganizationLedger) --
  # changing it from either page has the same effect, including cascading to
  # undo matches that would span it. Unlike the matcher, this view doesn't
  # filter transactions down to after_cutoff -- it shows the full history
  # (declined transactions included, which the matcher's ledger excludes) and
  # just flags which row the cutoff falls on, matched by id rather than the
  # matcher's index since the two lists aren't in the same order or filtered
  # the same way.
  def index
    ledger = OrganizationLedger.new(hcb_client, organization_id)
    transactions = Hcb::OrganizationTransactions.new(hcb_client, organization_id).all
    sorted = transactions.sort_by { |t| [ t["date"].to_s, t["id"].to_s ] }
    cutoff = ledger.effective_cutoff

    running = 0.0
    rows = sorted.map do |t|
      presenter = Hcb::TransactionPresenter.new(t)
      running = (running + presenter.amount).round(2)
      presenter.as_json.merge(running_balance: running, is_zero_point: cutoff&.transaction_id == presenter.id)
    end

    render json: {
      zero_balance_date: cutoff&.date,
      zero_balance_selected_id: cutoff&.transaction_id,
      zero_balance_options: ledger.zero_options.map { |o| { date: o.date, transaction_id: o.transaction_id, beginning: o.beginning? } },
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
