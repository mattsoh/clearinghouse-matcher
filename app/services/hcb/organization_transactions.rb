module Hcb
  # Drains HCB's cursor-paginated transactions endpoint into one array per
  # organization and caches it, so the bulk, unpaginated JSON the frontend
  # expects doesn't mean hitting HCB on every request. The org-shared HCB
  # rate limit (1000 req / 5 min / IP) is the reason this exists at all.
  #
  # Drains the FULL history: the zero-balance cutoff and the ledger's running
  # balance are only correct when computed from the account's first
  # transaction, so a rolling window isn't an option here. Worst case for a
  # busy org is a few dozen requests per cache fill, well within budget.
  class OrganizationTransactions
    TTL = ENV.fetch("HCB_TRANSACTION_CACHE_TTL", 120).to_i.seconds
    PAGE_SIZE = 100

    def initialize(client, organization_id, filters: {})
      @client = client
      @organization_id = organization_id
      @filters = filters.compact.deep_stringify_keys
    end

    def page(after: nil, limit: PAGE_SIZE)
      @client.transactions(@organization_id, after: after, limit: limit, filters: @filters)
    end

    def all(bypass_cache: false)
      return drain if bypass_cache

      Rails.cache.fetch(cache_key, expires_in: TTL, race_condition_ttl: 10.seconds) { drain }
    end

    # One HCB page per call, for callers that want to render transactions as
    # soon as each page resolves instead of blocking on the full multi-page
    # drain. Short-circuits to the cached #all result when it's already warm.
    #
    # Accumulates pages under a caller-supplied stream_id (rather than the
    # shared cache_key) so two concurrent drains -- two tabs, two users --
    # can't interleave and corrupt each other's buffer. Once the last page
    # comes back, the accumulated result is written to the same cache_key
    # #all reads, so the caller's next request for the fully-computed view
    # doesn't re-drain from scratch.
    def fetch_page(stream_id:, after: nil, limit: PAGE_SIZE)
      if after.blank?
        cached = Rails.cache.read(cache_key)
        return { data: cached, has_more: false, next_after: nil, total_count: cached.size } if cached
      end

      raw = page(after: after, limit: limit)
      data = raw["data"] || []
      has_more = data.any? && raw["has_more"]

      buffered = (Rails.cache.read(buffer_key(stream_id)) || []) + data

      if has_more
        Rails.cache.write(buffer_key(stream_id), buffered, expires_in: 2.minutes)
      else
        Rails.cache.write(cache_key, buffered, expires_in: TTL)
        Rails.cache.delete(buffer_key(stream_id))
      end

      { data: data, has_more: has_more, next_after: has_more ? data.last["id"] : nil, total_count: raw["total_count"] }
    end

    private

    def buffer_key(stream_id) = "#{cache_key}:buffer:#{stream_id}"

    def cache_key = "hcb:org:#{@organization_id}:transactions:v2:#{filters_cache_key}"

    def filters_cache_key
      @filters.to_a.sort_by(&:first).to_h.to_json
    end

    def drain
      results = []
      after = nil

      loop do
        page = self.page(after: after, limit: PAGE_SIZE)
        data = page["data"] || []
        results.concat(data)

        break if data.empty? || !page["has_more"]

        after = data.last["id"]
      end

      results
    end
  end
end
