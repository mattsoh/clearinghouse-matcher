require "test_helper"

class Api::LedgerControllerTest < ActionController::TestCase
  def setup
    @user = User.create!(hcb_user_id: "usr_1", access_token: "a", refresh_token: "b", token_expires_at: 1.hour.from_now)
    session[:user_id] = @user.id
  end

  test "index reports the same effective cutoff as the matcher, flagging the right row" do
    raw = [
      { "id" => "txn_4", "date" => "2026-01-04", "memo" => "Grant 2", "amount_cents" => -5_000 },
      { "id" => "txn_3", "date" => "2026-01-03", "memo" => "Donation 2", "amount_cents" => 5_000 },
      { "id" => "txn_2", "date" => "2026-01-02", "memo" => "Grant 1", "amount_cents" => -10_000 },
      { "id" => "txn_1", "date" => "2026-01-01", "memo" => "Donation 1", "amount_cents" => 10_000 }
    ]
    fake_client = FakeHcbClient.new(transactions: raw)

    Hcb::Client.stub :new, fake_client do
      stub_membership("reader") do
        get :index, params: { organization_id: "org_1" }
      end
    end

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "txn_4", body["zero_balance_selected_id"]
    assert_equal "2026-01-04", body["zero_balance_date"]

    zero_point_ids = body["ledger"].select { |r| r["is_zero_point"] }.map { |r| r["id"] }
    assert_equal [ "txn_4" ], zero_point_ids

    beginning = body["zero_balance_options"].find { |o| o["transaction_id"] == OrganizationLedger::BEGINNING_ID }
    assert beginning
    assert_equal true, beginning["beginning"]
  end

  test "index honors a persisted cutoff choice shared with the matcher" do
    raw = [
      { "id" => "txn_4", "date" => "2026-01-04", "memo" => "Grant 2", "amount_cents" => -5_000 },
      { "id" => "txn_3", "date" => "2026-01-03", "memo" => "Donation 2", "amount_cents" => 5_000 },
      { "id" => "txn_2", "date" => "2026-01-02", "memo" => "Grant 1", "amount_cents" => -10_000 },
      { "id" => "txn_1", "date" => "2026-01-01", "memo" => "Donation 1", "amount_cents" => 10_000 }
    ]
    fake_client = FakeHcbClient.new(transactions: raw)
    OrganizationSetting.create!(hcb_organization_id: "org_1", zero_balance_transaction_id: OrganizationLedger::BEGINNING_ID, updated_by: @user)

    Hcb::Client.stub :new, fake_client do
      stub_membership("reader") do
        get :index, params: { organization_id: "org_1" }
      end
    end

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal OrganizationLedger::BEGINNING_ID, body["zero_balance_selected_id"]
    assert_empty body["ledger"].select { |r| r["is_zero_point"] }
  end

  test "page returns presented transactions for a stream_id, with no more pages left" do
    fake_client = FakeHcbClient.new(transactions: [
      { "id" => "txn_2", "date" => "2026-01-02", "memo" => "Grant", "amount_cents" => -5_000 },
      { "id" => "txn_1", "date" => "2026-01-01", "memo" => "Donation", "amount_cents" => 5_000 }
    ])

    Hcb::Client.stub :new, fake_client do
      stub_membership("reader") do
        get :page, params: { organization_id: "org_1", stream_id: "s1" }
      end
    end

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ "txn_2", "txn_1" ], body["rows"].map { |t| t["id"] }
    assert_not body["has_more"]
    assert_nil body["next_after"]
  end
end
