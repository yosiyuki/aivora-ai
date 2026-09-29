module Knowledge
  # The Phase 1 product KPIs (README §36), computed from rows the system
  # already keeps. Rates are kept here as numbers for evaluation (§35); the
  # dashboard turns them into sentences, because "3 件中 2 件" tells the owner
  # something and "67%" does not.
  #
  # Rollback Rate needs the decision ledger (#52) and is nil until then.
  class Kpi
    def self.for(site) = new(site)

    def initialize(site)
      @site = site
    end

    # --- Verification Completion Rate -----------------------------------------
    # answered / (answered + open + closed). A superseded request is one whose
    # question stopped mattering, so it is neither asked nor answered; a
    # closed one was set aside by the owner and still counts as unanswered.

    def requests_answered = request_counts.fetch("answered", 0)
    def requests_open = request_counts.fetch("open", 0)
    def requests_closed = request_counts.fetch("closed", 0)
    def requests_asked = requests_answered + requests_open + requests_closed

    def verification_completion_rate
      requests_asked.zero? ? nil : requests_answered.to_f / requests_asked
    end

    # --- Stale Fact Reduction (this month) -------------------------------------
    # Of the facts that went stale this month, how many were confirmed again.
    # Going stale writes a knowledge_versions snapshot with status "stale",
    # and re-accepting writes another, so the history is already there.

    def facts_gone_stale
      @facts_gone_stale ||= KnowledgeVersion.where(knowledge_type: "Fact", created_at: month)
                                            .where("snapshot->>'status' = 'stale'")
                                            .distinct.pluck(:knowledge_id)
    end

    def facts_recovered
      @facts_recovered ||= @site.facts.where(id: facts_gone_stale, status: "accepted").count
    end

    def stale_fact_reduction
      facts_gone_stale.empty? ? nil : facts_recovered.to_f / facts_gone_stale.size
    end

    # --- Unsupported Claim Rate / Groundedness (published pages) ---------------
    # Over the claims of every published version. Verifiable claims that ended
    # blank or excised are the unsupported ones; general claims are not
    # site-specific and sit outside both rates.

    def verifiable_claims = published_claims.where(claim_kind: "verifiable").count
    def unsupported_claims = published_claims.where(claim_kind: "verifiable", review_status: %w[blank excised]).count

    def unsupported_claim_rate
      verifiable_claims.zero? ? nil : unsupported_claims.to_f / verifiable_claims
    end

    def groundedness
      scoped = published_claims.where.not(claim_kind: "general")
      total = scoped.count
      total.zero? ? nil : scoped.where(review_status: "grounded").count.to_f / total
    end

    # --- the others -------------------------------------------------------------

    def cost_per_page = Llm::Usage::Report.for(@site).cost_per_page
    def rollback_rate = nil   # decision ledger, #52

    private

    def request_counts = @request_counts ||= @site.verification_requests.group(:status).count

    def published_claims
      ContentClaim.joins(content_version: :content_item)
                  .where(content_items: { site_id: @site.id, status: "published" })
                  .where("content_versions.id = content_items.published_version_id")
    end

    def month = Time.use_zone(@site.timezone) { Time.current.all_month }
  end
end
