require "test_helper"

class UserTest < ActiveSupport::TestCase
  def build_user(**overrides)
    User.new({ hcb_user_id: "usr_1", access_token: "tok", refresh_token: "ref", token_expires_at: 1.hour.from_now }.merge(overrides))
  end

  test "requires a unique hcb_user_id" do
    build_user.save!
    duplicate = build_user
    assert_not duplicate.valid?
  end

  test "encrypts access_token and refresh_token at rest" do
    user = build_user
    user.save!

    raw = ActiveRecord::Base.connection.select_one("SELECT access_token FROM users WHERE id = #{user.id}")
    assert_not_equal "tok", raw["access_token"]
    assert_equal "tok", user.reload.access_token
  end

  test "token_fresh? is false once within the buffer window" do
    user = build_user(token_expires_at: 30.seconds.from_now)
    assert_not user.token_fresh?
  end

  test "token_fresh? is true well before expiry" do
    user = build_user(token_expires_at: 1.hour.from_now)
    assert user.token_fresh?
  end
end
