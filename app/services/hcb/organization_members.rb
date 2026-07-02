module Hcb
  # Looks up org membership/role. Cached per-organization (not per-user) since
  # one `expand[]=users` call returns every member's role at once.
  class OrganizationMembers
    ROLES = %w[reader member manager].freeze
    TTL = ENV.fetch("HCB_MEMBERS_CACHE_TTL", 60).to_i.seconds

    def self.role_for(client:, organization_id:, hcb_user_id:)
      new(client, organization_id).role_for(hcb_user_id)
    end

    def initialize(client, organization_id)
      @client = client
      @organization_id = organization_id
    end

    def role_for(hcb_user_id)
      member = members.find { |u| u["id"] == hcb_user_id }
      member && member["role"]
    end

    private

    def members
      Rails.cache.fetch(cache_key, expires_in: TTL, race_condition_ttl: 5.seconds) do
        organization = @client.organization(@organization_id, expand: [ "users" ])
        organization["users"] || []
      end
    end

    def cache_key = "hcb:org:#{@organization_id}:members:v1"
  end
end
