module Verification
  # Finds facts nobody has confirmed within their risk window, stops publishing
  # them, and asks the owner to check (README §14 use (1)).
  #
  # This is observation, which is fixed cost and never stops — including while
  # the month's budget is spent (README §33). It calls no model, so there is
  # nothing to degrade: the work is two columns and a comparison.
  class StalenessJob < ApplicationJob
    queue_as :default

    def perform(site_id = nil)
      sites(site_id).each { |site| sweep(site) }
    end

    private

    def sites(site_id) = site_id ? Site.where(id: site_id) : Site.all

    def sweep(site)
      requester = Requester.new(site)
      Staleness.stale_facts(site).each do |fact|
        # Mark first: a fact that should not be published must stop being
        # published even if raising the question fails.
        fact.mark_stale!
        requester.issue_recheck(fact)
      end
    end
  end
end
