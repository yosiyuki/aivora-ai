require "rails_helper"

RSpec.describe Knowledge::Kpi do
  let!(:site) { cafe_site }

  def request!(status)
    r = site.verification_requests.create!(request_type: "initial", slot_key: "hours", question: "q", priority: 1)
    r.update!(status: status) unless status == "open"
    r
  end

  def stale_then!(recover:)
    fact = site.primary_entity.facts.create!(attribute_key: "営業時間", slot_key: "hours",
                                             value_json: { "value" => "7-17" }, confidence: 0.9, risk_level: "high")
    fact.accept!(evidence: owner_evidence(site, text: "7-17 です"))
    fact.mark_stale!
    fact.accept!(evidence: owner_evidence(site, text: "いまも 7-17 です")) if recover
    fact
  end

  describe "verification completion" do
    it "counts answered over asked, leaving superseded out and closed in" do
      request!("answered"); request!("answered"); request!("open"); request!("closed"); request!("superseded")

      kpi = described_class.for(site)

      expect(kpi.requests_asked).to eq(4)
      expect(kpi.verification_completion_rate).to eq(0.5)
    end

    it "is nil before anything has been asked" do
      expect(described_class.for(site).verification_completion_rate).to be_nil
    end
  end

  describe "stale fact reduction" do
    it "is recovered over gone-stale for this month" do
      stale_then!(recover: true)
      stale_then!(recover: false)

      kpi = described_class.for(site)

      expect(kpi.facts_gone_stale.size).to eq(2)
      expect(kpi.facts_recovered).to eq(1)
      expect(kpi.stale_fact_reduction).to eq(0.5)
    end

    it "ignores a fact that went stale last month" do
      travel_to(40.days.ago) { stale_then!(recover: false) }   # versions are append-only, so backdate by living there

      expect(described_class.for(site).stale_fact_reduction).to be_nil
    end
  end

  describe "unsupported claims and groundedness on published pages" do
    it "counts blank and excised verifiable claims against all verifiable ones" do
      stub_generation
      Content::GenerateJob.perform_now(site.id, "top")

      kpi = described_class.for(site)

      expect(kpi.verifiable_claims).to eq(2)
      expect(kpi.unsupported_claims).to eq(0), "the cafe draft's placeholder is a metadata blank, not a claim row"
      expect(kpi.unsupported_claim_rate).to eq(0.0)
      expect(kpi.groundedness).to eq(1.0), "general claims sit outside the rate"
    end

    it "is nil with nothing published" do
      kpi = described_class.for(site)

      expect(kpi.unsupported_claim_rate).to be_nil
      expect(kpi.groundedness).to be_nil
    end
  end

  it "defers rollback rate to the decision ledger and delegates cost per page" do
    kpi = described_class.for(site)

    expect(kpi.rollback_rate).to be_nil
    expect(kpi.cost_per_page).to eq(Llm::Usage::Report.for(site).cost_per_page)
  end
end
