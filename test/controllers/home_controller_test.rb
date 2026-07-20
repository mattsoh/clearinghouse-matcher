require "test_helper"

class HomeControllerTest < ActionController::TestCase
  test "renders the home page with a login link for signed-out visitors" do
    get :index
    assert_response :success
    assert_select "a[href=?]", login_path, text: "Log in with HCB"
  end

  test "redirects signed-in users to their organizations" do
    user = User.create!(hcb_user_id: "usr_1", access_token: "a", refresh_token: "b", token_expires_at: 1.hour.from_now)
    session[:user_id] = user.id

    get :index
    assert_redirected_to organizations_path
  end
end
