module Verification
  # When a fact stops being trustworthy because nobody has confirmed it lately
  # (README §13, TechnicalArchitecture §18).
  #
  # Computed, not stored. `last_verified_at` and `risk_level` are enough to
  # answer the question at any moment, and a stored verdict would become a
  # second truth that disagrees with them the day after it is written.
  # DatabaseSchema §21 defines a fact_staleness table; §75 does not list it
  # among the Phase 1 minimum, so it stays unbuilt until something needs to
  # keep `stale_reason` around.
  module Staleness
    # A wrong opening time sends someone to a closed door; a wrong description
    # of what a shop is about does not. Risk decides how long an unconfirmed
    # value is still worth publishing.
    TTL = { "high" => 90.days, "medium" => 180.days, "low" => 365.days }.freeze

    module_function

    # Experiential knowledge does not expire. "静かで落ち着ける" stays true until
    # the owner says otherwise, so only facts are considered here at all.
    def stale?(fact, now: Time.current)
      return false unless fact.accepted?

      verified = fact.last_verified_at or return true
      verified <= now - ttl_for(fact)
    end

    def ttl_for(fact) = TTL.fetch(fact.risk_level, TTL["medium"])

    # When this fact stops being publishable, for ordering the work.
    def stale_at(fact)
      verified = fact.last_verified_at or return Time.current
      verified + ttl_for(fact)
    end

    # The facts a site should stop publishing until someone confirms them.
    def stale_facts(site, now: Time.current)
      site.facts.where(status: "accepted").select { |fact| stale?(fact, now: now) }
    end
  end
end
