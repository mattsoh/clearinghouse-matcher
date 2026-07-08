module Hcb
  # Looks up org membership/role, and resolves the route param (which HCB
  # accepts as either the org's immutable id or its mutable slug) to the
  # immutable id so callers never persist a slug. Cached per-organization
  # (not per-user) since one `expand[]=users` call returns every member's
  # role at once.
  class OrganizationMembers
    ROLES = %w[reader member manager].freeze
    TTL = ENV.fetch("HCB_MEMBERS_CACHE_TTL", 60).to_i.seconds

    Membership = Struct.new(:organization_id, :organization_slug, :role, keyword_init: true)

    def self.role_for(client:, organization_id:, hcb_user_id:)
      new(client, organization_id).role_for(hcb_user_id)
    end

    def initialize(client, organization_id)
      @client = client
      @organization_id = organization_id
    end

    def role_for(hcb_user_id)
      member = (organization["users"] || []).find { |u| u["id"] == hcb_user_id }
      Membership.new(organization_id: organization["id"], organization_slug: organization["slug"], role: member && member["role"])
    end

    private

    # HCB answers a nonexistent org and one the token just isn't authorized
    # for identically (403 not_authorized), matching the caller's own
    # can't-distinguish-the-two stance (see OrganizationScoped#role_for) --
    # so it's treated as "no such org" here rather than an unhandled error.
    def organization
      Rails.cache.fetch(cache_key, expires_in: TTL, race_condition_ttl: 5.seconds) do
        @client.organization(@organization_id, expand: [ "users" ])
      end
    rescue OAuth2::Error => e
      raise unless e.response.status.in?([ 403, 404 ])
      {}
    end

    def cache_key = "hcb:org:#{@organization_id}:members:v1"
  end
end
