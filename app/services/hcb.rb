module Hcb
  class TokenExpiredError < StandardError; end

  def self.oauth_client
    OAuth2::Client.new(
      ENV.fetch("HCB_OAUTH_CLIENT_ID"),
      ENV.fetch("HCB_OAUTH_CLIENT_SECRET"),
      site: ENV.fetch("HCB_API_BASE_URL", "https://hcb.hackclub.com"),
      authorize_url: "/api/v4/oauth/authorize",
      token_url: "/api/v4/oauth/token"
    )
  end
end
