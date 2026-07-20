require "test_helper"

class ErrorPagesTest < ActiveSupport::TestCase
  test "config.exceptions_app dispatches /404 to the branded error page" do
    env = Rack::MockRequest.env_for("/404")
    status, _headers, body = Rails.application.config.exceptions_app.call(env)

    assert_equal 404, status
    assert_includes body.each.to_a.join, "Page not found"
  end
end
