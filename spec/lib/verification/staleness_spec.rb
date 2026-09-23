require "rails_helper"

RSpec.describe Verification::Staleness do
  let!(:site) { cafe_site }

  def accepted_fact(risk_level: "medium", verified_at: Time.current, slot_key: "hours")
    fact = site.primary_entity.facts.create!(attribute_key: "営業時間", slot_key: slot_key,
                                             value_json: { "value" => "7時-17時" },
                                             confidence: 0.9, risk_level: risk_level)
    fact.accept!(evidence: owner_evidence(site, text: "7時から17時まで開けています"), verified_at: verified_at)
    fact
  end

  it "gives a shorter life to a fact that hurts when it is wrong" do
    expect(described_class.ttl_for(accepted_fact(risk_level: "high"))).to eq(90.days)
    expect(described_class.ttl_for(accepted_fact(risk_level: "medium", slot_key: "contact"))).to eq(180.days)
    expect(described_class.ttl_for(accepted_fact(risk_level: "low", slot_key: "access"))).to eq(365.days)
  end

  it "holds a fact fresh inside its window and lets it go outside" do
    fact = accepted_fact(risk_level: "high", verified_at: 89.days.ago)

    expect(described_class).not_to be_stale(fact)

    fact.update_columns(last_verified_at: 91.days.ago)

    expect(described_class).to be_stale(fact.reload)
  end

  it "does not expire a fact nobody has accepted" do
    candidate = site.primary_entity.facts.create!(attribute_key: "営業時間", slot_key: "hours",
                                                  value_json: { "value" => "7時-17時" }, confidence: 0.9)

    expect(described_class).not_to be_stale(candidate), "a candidate was never published to begin with"
  end

  it "collects the facts a site should stop publishing" do
    fresh = accepted_fact(risk_level: "high", verified_at: 10.days.ago)
    old = accepted_fact(risk_level: "high", verified_at: 200.days.ago, slot_key: "contact")

    stale = described_class.stale_facts(site.reload)

    expect(stale).to include(old)
    expect(stale).not_to include(fresh)
  end

  it "says when a fact will need checking, for ordering the work" do
    fact = accepted_fact(risk_level: "high", verified_at: Time.utc(2026, 1, 1))

    expect(described_class.stale_at(fact)).to be_within(1.second).of(Time.utc(2026, 1, 1) + 90.days)
  end
end
