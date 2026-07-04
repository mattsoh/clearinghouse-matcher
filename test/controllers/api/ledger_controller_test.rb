require "test_helper"

class Api::LedgerControllerTest < ActionController::TestCase
  def setup
    @user = User.create!(hcb_user_id: "usr_1", access_token: "a", refresh_token: "b", token_expires_at: 1.hour.from_now)
    session[:user_id] = @user.id
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
