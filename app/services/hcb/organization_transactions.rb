module Hcb
  # Drains HCB's cursor-paginated transactions endpoint into one array per
  # organization and caches it, so the bulk, unpaginated JSON the frontend
  # expects doesn't mean hitting HCB on every request. The org-shared HCB
  # rate limit (1000 req / 5 min / IP) is the reason this exists at all.
  class OrganizationTransactions
    WINDOW_DAYS = ENV.fetch("HCB_TRANSACTION_WINDOW_DAYS", 180).to_i
    TTL = ENV.fetch("HCB_TRANSACTION_CACHE_TTL", 120).to_i.seconds
    PAGE_SIZE = 100

    def initialize(client, organization_id)
      @client = client
      @organization_id = organization_id
    end

    # bypass_cache: true also disables the WINDOW_DAYS cutoff, since the only
    # caller that needs uncached data is the one-off legacy migration task,
    # which needs full history rather than the live app's rolling window.
    def all(bypass_cache: false)
      return drain(cutoff: nil) if bypass_cache

      Rails.cache.fetch(cache_key, expires_in: TTL, race_condition_ttl: 10.seconds) do
        drain(cutoff: WINDOW_DAYS.days.ago)
      end
    end

    private

    def cache_key = "hcb:org:#{@organization_id}:transactions:v1"

    def drain(cutoff:)
      results = []
      after = nil

      loop do
        page = @client.transactions(@organization_id, after: after, limit: PAGE_SIZE)
        data = page["data"] || []
        results.concat(data)

        last = data.last
        break if last.nil?
        break unless page["has_more"]
        break if cutoff && last["date"] && last["date"] < cutoff.iso8601

        after = last["id"]
      end

      results
    end
  end
end
