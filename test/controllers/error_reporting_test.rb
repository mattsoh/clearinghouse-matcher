require "test_helper"

class ErrorReportingTest < ActionController::TestCase
  tests OrganizationsController

  def setup
    @user = User.create!(hcb_user_id: "usr_1", access_token: "a", refresh_token: "b", token_expires_at: 1.hour.from_now)
    session[:user_id] = @user.id
  end

  test "unexpected errors render a code and are reported to AppSignal with that code" do
    reported_exception = nil
    reported_tags = nil

    Appsignal.stub :set_error, ->(exception) { reported_exception = exception } do
      Appsignal.stub :add_tags, ->(tags) { reported_tags = tags } do
        Rails.env.stub :local?, false do
          Rails.cache.stub :fetch, ->(*) { raise "boom" } do
            get :index
          end
        end
      end
    end

    assert_response :internal_server_error
    assert_kind_of RuntimeError, reported_exception
    assert_equal "boom", reported_exception.message

    error_id = reported_tags[:error_id]
    assert_match(/\A[0-9A-F]{8}\z/, error_id)
    assert_includes response.body, error_id
  end

  test "in development/test, unexpected errors are not swallowed" do
    assert_raises(RuntimeError) do
      Rails.cache.stub :fetch, ->(*) { raise "boom" } do
        get :index
      end
    end
  end
end
