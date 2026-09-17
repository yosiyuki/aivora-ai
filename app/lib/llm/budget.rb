module Llm
  # The monthly LLM spend ceiling and what to do when it is reached
  # (README §33, Technical Architecture §38).
  #
  # Cost is the throttle on generation volume, so this is read before every
  # call. On overrun the answer is always `degrade` — keep running on a
  # smaller model — never stop: stopping would stop observation too, and
  # stale facts would go undetected while the site keeps serving them.
  class Budget
    # Resolved once per request or job. Recomputing per call would re-run the
    # monthly aggregate several times for a single page.
    def self.for(site)
      return none if site.nil?

      Current.llm_budgets ||= {}
      Current.llm_budgets[site.id] ||= new(site)
    end

    def self.none = @none ||= Unlimited.new

    def initialize(site)
      @site = site
    end

    def limit = policy.monthly_budget

    # Failed calls count. A refusal or a truncated answer is still billed, and
    # LlmUsage records the billed cost for exactly that reason; only transport
    # errors carry no usage, and those are already zero.
    def spent
      @spent ||= LlmUsage.where(site: @site, created_at: month_range).sum(:estimated_cost)
    end

    def exceeded? = spent >= limit

    # Phase 1 degrades whatever budget_action says (SitePolicy#degrade_only?).
    def degraded? = exceeded?

    def remaining = [ limit - spent, 0 ].max

    # A site's month is its own: the aggregate must not shift by a day because
    # the server runs in another zone.
    def month_range
      Time.use_zone(@site.timezone) { Time.current.all_month }
    end

    def policy = @policy ||= @site.policy

    # Used when there is no site yet (setup, or a call outside a site).
    class Unlimited
      def limit = Float::INFINITY
      def spent = 0
      def exceeded? = false
      def degraded? = false
      def remaining = Float::INFINITY
    end
  end
end
