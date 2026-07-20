require "test_helper"

class ErrorsControllerTest < ActionController::TestCase
  tests ErrorsController

  test "renders a 404 page with a link home" do
    get :not_found
    assert_response :not_found
    assert_select "a[href=?]", root_path, text: "Go back home"
  end

  test "renders a 422 page" do
    get :unprocessable_entity
    assert_response :unprocessable_entity
  end

  test "renders a 400 page" do
    get :bad_request
    assert_response :bad_request
  end

  test "renders a 500 page with an error code and reports it to AppSignal if an exception is present" do
    exception = RuntimeError.new("boom")
    reported_exception = nil
    reported_tags = nil

    @request.env["action_dispatch.exception"] = exception

    Appsignal.stub :set_error, ->(e) { reported_exception = e } do
      Appsignal.stub :add_tags, ->(tags) { reported_tags = tags } do
        get :internal_server_error
      end
    end

    assert_response :internal_server_error
    assert_equal exception, reported_exception

    error_id = reported_tags[:error_id]
    assert_match(/\A[0-9A-F]{8}\z/, error_id)
    assert_includes response.body, error_id
  end
end
