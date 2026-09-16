module Llm
  module Usage
    # What the month's LLM spend bought, in the words a non-expert can act on
    # (README §33). "4本作りました。あと2本ほど作れます" changes a decision;
    # "$32 使いました" does not.
    #
    # Money is kept, but secondary: the owner is never asked to predict usage.
    class Report
      # Generation is the variable cost; extraction and entity resolution are
      # the fixed cost of observing (Technical Architecture §38). Only the
      # variable part divides into a per-page figure, or the fixed cost of
      # running the interview would inflate what a page appears to cost.
      GENERATION_OPERATIONS = %w[drafting grounding planning].freeze

      # Until a site has generated anything there is no measured rate, and
      # answering "0 more pages" would be wrong. README §33's conservative
      # figure ($50 buys 3-5 pages) gives the starting estimate.
      ESTIMATED_PAGES_PER_50_USD = 4

      def self.for(site) = new(site)

      def initialize(site)
        @site = site
      end

      def budget = @budget ||= Budget.for(@site)
      def limit = budget.limit
      def spent = budget.spent
      def remaining = budget.remaining
      def degraded? = budget.degraded?

      # Pages that reached publication this month. A version that failed
      # grounding cost money but bought nothing, so it is not counted.
      def pages_this_month
        @pages_this_month ||= ContentVersion.joins(:content_item)
                                            .where(content_items: { site_id: @site.id })
                                            .where(grounding_status: "passed", created_at: budget.month_range)
                                            .count
      end

      def generation_spend
        @generation_spend ||= usage.where(operation_type: GENERATION_OPERATIONS).sum(:estimated_cost)
      end

      def observation_spend = spent - generation_spend

      # nil rather than 0 when nothing has been generated: the caller has to
      # decide what to say, and "costs nothing" would be a lie.
      def cost_per_page
        return nil if pages_this_month.zero? || generation_spend.zero?

        generation_spend / pages_this_month
      end

      # How many more pages this month's remaining budget buys.
      def remaining_pages
        rate = cost_per_page || estimated_cost_per_page
        return 0 if rate.zero?

        (remaining / rate).floor
      end

      def estimated? = cost_per_page.nil?

      # Model routing is reviewed from this (§37). Deliberately not shown to
      # the owner: operation names are our vocabulary, not theirs.
      def by_operation
        usage.group(:operation_type).sum(:estimated_cost)
      end

      private

      def usage = LlmUsage.where(site: @site, created_at: budget.month_range)

      def estimated_cost_per_page
        BigDecimal("50") / ESTIMATED_PAGES_PER_50_USD
      end
    end
  end
end
