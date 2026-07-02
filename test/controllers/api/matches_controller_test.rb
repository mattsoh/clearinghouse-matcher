require "test_helper"

class Api::MatchesControllerTest < ActionController::TestCase
  def setup
    @user = User.create!(hcb_user_id: "usr_1", access_token: "a", refresh_token: "b", token_expires_at: 1.hour.from_now)
    incoming = { "id" => "txn_in", "date" => "2026-01-01", "memo" => "Donation", "amount_cents" => 10_000 }
    outgoing = { "id" => "txn_out", "date" => "2026-01-02", "memo" => "Grant", "amount_cents" => -10_000 }
    @fake_client = FakeHcbClient.new(transactions: [ incoming, outgoing ])
    session[:user_id] = @user.id
  end

  test "unauthenticated requests are redirected to login" do
    session[:user_id] = nil
    get :index, params: { organization_id: "org_1" }
    assert_redirected_to login_path
  end

  test "a non-member is forbidden" do
    Hcb::Client.stub :new, @fake_client do
      Hcb::OrganizationMembers.stub :role_for, nil do
        get :index, params: { organization_id: "org_1" }
      end
    end
    assert_response :forbidden
  end

  test "a reader can list matches but cannot create one" do
    Hcb::Client.stub :new, @fake_client do
      Hcb::OrganizationMembers.stub :role_for, "reader" do
        get :index, params: { organization_id: "org_1" }
        assert_response :success

        post :create, params: { organization_id: "org_1", incoming_ids: [ "txn_in" ], outgoing_ids: [ "txn_out" ] }
        assert_response :forbidden
      end
    end
  end

  test "a member can create and then undo a match" do
    Hcb::Client.stub :new, @fake_client do
      Hcb::OrganizationMembers.stub :role_for, "member" do
        post :create, params: { organization_id: "org_1", incoming_ids: [ "txn_in" ], outgoing_ids: [ "txn_out" ] }
        assert_response :created
        match_id = JSON.parse(response.body)["id"]

        delete :destroy, params: { organization_id: "org_1", id: match_id }
        assert_response :success
        assert Match.find(match_id).undone?
      end
    end
  end

  test "matching the same transaction twice returns a conflict" do
    Hcb::Client.stub :new, @fake_client do
      Hcb::OrganizationMembers.stub :role_for, "manager" do
        post :create, params: { organization_id: "org_1", incoming_ids: [ "txn_in" ], outgoing_ids: [] }
        assert_response :created

        post :create, params: { organization_id: "org_1", incoming_ids: [ "txn_in" ], outgoing_ids: [] }
        assert_response :conflict
      end
    end
  end
end
