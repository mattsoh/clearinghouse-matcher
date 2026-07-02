require "test_helper"

class Matches::UndoTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(hcb_user_id: "usr_1", access_token: "a", refresh_token: "b", token_expires_at: 1.hour.from_now)
    @match = Match.create!(hcb_organization_id: "org_1", discrepancy_cents: 0, created_by: @user)
    @match.match_transactions.create!(hcb_organization_id: "org_1", hcb_transaction_id: "txn_in", direction: :incoming)
  end

  test "marks the match and its transactions as undone" do
    result = Matches::Undo.new(match: @match, user: @user).call
    assert result.success?
    assert @match.reload.undone?
    assert_equal @user, @match.undone_by
    assert @match.match_transactions.first.undone_at.present?
  end

  test "frees the transaction up for a new match" do
    Matches::Undo.new(match: @match, user: @user).call

    new_match = Match.create!(hcb_organization_id: "org_1", discrepancy_cents: 0, created_by: @user)
    assert_nothing_raised do
      new_match.match_transactions.create!(hcb_organization_id: "org_1", hcb_transaction_id: "txn_in", direction: :incoming)
    end
  end

  test "returns not_found for a missing match" do
    result = Matches::Undo.new(match: nil, user: @user).call
    assert_not result.success?
    assert_equal :not_found, result.status
  end

  test "cannot undo an already-undone match" do
    Matches::Undo.new(match: @match, user: @user).call
    result = Matches::Undo.new(match: @match, user: @user).call
    assert_not result.success?
  end
end
