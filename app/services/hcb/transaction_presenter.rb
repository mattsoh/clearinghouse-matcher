module Hcb
  # Normalizes a raw HCB v4 transaction JSON hash into the field shape the
  # legacy frontend (app.js/ledger.js/details.js) already knows how to render.
  # Comments aren't included here -- HCB's comments endpoint is per-transaction,
  # so details.js fetches them on demand (via Api::CommentsController) only
  # when the detail modal for a transaction is opened, rather than paying for
  # one extra API call per row up front. `user_name` is only populated for
  # transaction types that
  # carry an internal HCB "sender"/"submitter" (ACH transfers, checks,
  # disbursements, Wise transfers, card charges, check deposits) -- see
  # app/views/api/v4/transactions/*.json.jbuilder in hackclub/hcb. Donations
  # and invoices are paid by external, non-HCB-account parties, so they have
  # no user to attribute.
  class TransactionPresenter
    # HCB's `code` is the numeric HcbCode type segment (e.g. "HCB-200-123" ->
    # "200"), not a human label. See TransactionGroupingEngine::Calculate::HcbCode
    # in hackclub/hcb for the authoritative list of codes.
    CATEGORY_NAMES = {
      "000" => "Uncategorized",
      "100" => "Invoice",
      "200" => "Donation",
      "201" => "Partner donation",
      "300" => "ACH transfer",
      "310" => "Wire",
      "350" => "PayPal transfer",
      "360" => "Wise transfer",
      "400" => "Check",
      "401" => "Increase check",
      "402" => "Check deposit",
      "500" => "Outgoing disbursement",
      "550" => "Incoming disbursement",
      "600" => "Stripe card",
      "601" => "Stripe force capture",
      "610" => "Stripe service fee",
      "700" => "Bank fee",
      "701" => "Incoming bank fee",
      "702" => "Fee revenue",
      "710" => "Expense payout",
      "712" => "Payout holding",
      "900" => "Outgoing fee reimbursement"
    }.freeze

    def initialize(raw)
      @raw = raw
    end

    def id = @raw["id"]
    def date = @raw["date"]
    def memo = @raw["memo"]
    def amount_cents = @raw["amount_cents"] || 0
    def amount = (amount_cents / 100.0).round(2)
    def direction = amount.negative? ? "out" : "in"
    def declined? = !!@raw["declined"]
    def tags = Array(@raw["tags"]).join(", ")
    def user_name
      @raw.dig("ach_transfer", "sender", "name") ||
        @raw.dig("check", "sender", "name") ||
        @raw.dig("transfer", "sender", "name") ||
        @raw.dig("wise_transfer", "sender", "name") ||
        @raw.dig("card_charge", "card", "user", "name") ||
        @raw.dig("check_deposit", "submitter", "name") ||
        ""
    end
    def category_label
      code = @raw["code"].to_s
      return "" if code.blank?

      name = CATEGORY_NAMES.fetch(code) { code.tr("_-", "  ").squish.capitalize }
      "#{name} (#{code})"
    end

    def as_json(*)
      {
        id: id, date: date, memo: memo, amount: amount, direction: direction,
        tags: tags, user_name: user_name, category_label: category_label
      }
    end
  end
end
