require "rails_helper"

RSpec.describe Knowledge::Health do
  let!(:site) { cafe_site }   # business: name/what/location minimum, hours/contact/offerings standard, story/access enriched

  def accept_fact!(slot_key, value: "x", risk_level: "medium", verified_at: Time.current)
    fact = site.primary_entity.facts.create!(attribute_key: slot_key, slot_key: slot_key,
                                             value_json: { "value" => value }, confidence: 0.9, risk_level: risk_level)
    fact.accept!(evidence: owner_evidence(site, text: "#{value} です"), verified_at: verified_at)
    fact
  end

  def fill_every_slot!
    site.required_slots.each { |s| accept_fact!(s.key) unless s.key == "location" }
  end

  it "is nil before an archetype gives the site any slots to score" do
    bare = Site.current
    bare.site_archetypes.destroy_all
    bare.update!(primary_archetype: nil)

    expect(described_class.for(bare.reload).score).to be_nil
  end

  it "scores 100 when every required slot has a fresh accepted fact" do
    fill_every_slot!

    expect(described_class.for(site).score).to eq(100)
    expect(described_class.for(site).by_slot.map(&:state).uniq).to eq([ :fresh ])
  end

  it "drops by the slot's weight when its fact goes stale" do
    fill_every_slot!
    hours = site.facts.for_slot("hours").first
    hours.update_columns(last_verified_at: 200.days.ago, risk_level: "high")

    health = described_class.for(site)
    total = site.required_slots.sum(&:weight)
    hours_w = site.required_slots.find { |s| s.key == "hours" }.weight

    expect(health.by_slot.find { |s| s.key == "hours" }.state).to eq(:stale)
    expect(health.score).to eq(((total - hours_w * 0.5) / total * 100).round)
    expect(health.stale_facts).to eq(1), "past its window counts even before the nightly sweep"
  end

  it "counts a missing slot as zero, whether or not a question is open" do
    fill_every_slot!
    site.facts.for_slot("contact").first.update_columns(status: "retired", valid_until: Time.current)
    site.verification_requests.create!(request_type: "initial", slot_key: "contact", question: "q", priority: 1)

    health = described_class.for(site)

    expect(health.by_slot.find { |s| s.key == "contact" }.state).to eq(:missing)
    expect(health.open_requests).to eq(1)
    expect(health.score).to be < 100
  end

  it "halves a slot with two accepted answers and counts them as conflicting" do
    fill_every_slot!
    accept_fact!("hours", value: "y")

    health = described_class.for(site)

    expect(health.by_slot.find { |s| s.key == "hours" }.state).to eq(:conflicting)
    expect(health.conflicting_facts).to eq(2)
  end

  it "ignores facts that answer no slot" do
    fill_every_slot!
    before = described_class.for(site).score
    site.primary_entity.facts.create!(attribute_key: "お土産", value_json: { "value" => "雑貨" }, confidence: 0.9)
      .accept!(evidence: owner_evidence(site, text: "雑貨があります"))
    Current.reset

    expect(described_class.for(site).score).to eq(before)
  end

  it "treats a slot the interview filled as fresh even without a slot-keyed fact" do
    interview = site.interviews.create!
    interview.update!(slot_state: { "what" => { "value" => "カフェ", "confidence" => 0.9 } })

    expect(described_class.for(site.reload).by_slot.find { |s| s.key == "what" }.state).to eq(:fresh)
  end

  it "counts the blanks a reader can see and the candidates still waiting for the owner" do
    stub_generation
    Content::GenerateJob.perform_now(site.id, "top")
    site.primary_entity.facts.create!(attribute_key: "営業時間", slot_key: "hours", value_json: { "value" => "7-17" }, confidence: 0.5)

    health = described_class.for(site.reload)

    expect(health.unverified_claims).to eq(0), "the drafter placeholder is a metadata blank, not a claim row"
    expect(health.missing_evidence).to eq(1)
    expect(health.fresh_facts).to eq(1)
  end
end
