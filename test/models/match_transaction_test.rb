require "test_helper"

class MatchTransactionTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(hcb_user_id: "usr_1", access_token: "a", refresh_token: "b", token_expires_at: 1.hour.from_now)
  end

  test "the DB rejects two active matches claiming the same org+transaction" do
    match_a = Match.create!(hcb_organization_id: "org_1", discrepancy_cents: 0, created_by: @user)
    match_b = Match.create!(hcb_organization_id: "org_1", discrepancy_cents: 0, created_by: @user)

    match_a.match_transactions.create!(hcb_organization_id: "org_1", hcb_transaction_id: "txn_1", direction: :incoming)

    assert_raises(ActiveRecord::RecordNotUnique) do
      match_b.match_transactions.create!(hcb_organization_id: "org_1", hcb_transaction_id: "txn_1", direction: :incoming)
    end
  end

  test "a transaction can be reused once its match is undone" do
    match_a = Match.create!(hcb_organization_id: "org_1", discrepancy_cents: 0, created_by: @user)
    match_b = Match.create!(hcb_organization_id: "org_1", discrepancy_cents: 0, created_by: @user)

    mt = match_a.match_transactions.create!(hcb_organization_id: "org_1", hcb_transaction_id: "txn_1", direction: :incoming)
    mt.update!(undone_at: Time.current)

    assert_nothing_raised do
      match_b.match_transactions.create!(hcb_organization_id: "org_1", hcb_transaction_id: "txn_1", direction: :incoming)
    end
  end

  test "the same transaction id can be active in two different organizations" do
    match_a = Match.create!(hcb_organization_id: "org_1", discrepancy_cents: 0, created_by: @user)
    match_b = Match.create!(hcb_organization_id: "org_2", discrepancy_cents: 0, created_by: @user)

    match_a.match_transactions.create!(hcb_organization_id: "org_1", hcb_transaction_id: "txn_1", direction: :incoming)

    assert_nothing_raised do
      match_b.match_transactions.create!(hcb_organization_id: "org_2", hcb_transaction_id: "txn_1", direction: :incoming)
    end
  end
end
