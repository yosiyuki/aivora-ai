require "rails_helper"

RSpec.describe Content::KnowledgePack do
  let!(:site) { cafe_site }
  let(:pack) { described_class.for(site, page_type: "top") }

  it "exposes facts and experiences by short refs and lists what is missing", :aggregate_failures do
    expect(pack.facts.map(&:ref)).to eq([ "F1" ])
    expect(pack.fact_by_ref("F1")).to have_attributes(attribute_key: "location", value: "渋谷")
    expect(pack.experiences.map(&:ref)).to eq(%w[E1 E2])
    expect(pack.experience_by_ref("E2").body).to include("長居")
    expect(pack.goals).to eq([ "近所の人にもっと来てほしい" ])
    expect(pack.slot_keys).to include("hours", "location")
    expect(pack.missing_slots.map(&:key)).to include("hours", "what")
    expect(pack.missing_slots.map(&:key)).not_to include("location"), "an accepted fact fills its slot"
    expect(pack.missing_slots.map(&:key)).not_to include("name"), "the primary entity is the name"
    expect(pack.placeholder_slots.map(&:kind).uniq).to eq([ "verifiable" ]), "only facts may become placeholders"
    expect(pack.to_prompt).to include("F1: 渋谷のカフェ の 場所 = 渋谷").and include("E1: 自家焙煎").and include("hours=営業時間")
    expect(pack.to_prompt).not_to include("what=")
  end

  it "only includes accepted, current facts" do
    entity = site.primary_entity
    entity.facts.create!(attribute_key: "hours", value_json: { "value" => "7-17" }, confidence: 0.5)   # candidate
    expect(described_class.for(site, page_type: "top").facts.map(&:attribute_key)).to eq([ "location" ])
  end

  it "scopes facts and experiences to the primary entity and orders facts by slot weight" do
    other = site.entities.create!(entity_type: "business", canonical_name: "他店")
    stray = other.facts.create!(attribute_key: "hours", value_json: { "value" => "9-18" }, confidence: 0.9)
    stray.accept!(evidence: owner_evidence(site, text: "他店は9時から"))
    site.experiences.create!(entity: other, summary: "他店の話", body: "他店は騒がしい", person_id: "owner")
    mine = site.primary_entity.facts.create!(attribute_key: "access", value_json: { "value" => "駅から3分" }, confidence: 0.9)
    mine.accept!(evidence: owner_evidence(site, text: "駅から3分"))

    pack = described_class.for(site, page_type: "top")
    expect(pack.facts.map(&:attribute_key)).to eq(%w[location access]), "weight 1.0 before 0.4; the other entity's fact is out"
    expect(pack.experiences.map(&:summary)).not_to include("他店の話")
    expect(pack.to_prompt).to include("渋谷のカフェ の 場所 = 渋谷")
  end

  it "marks the pack truncated when experiences exceed the body budget" do
    stub_const("Content::KnowledgePack::LIMITS", { facts: 200, experiences: 50, body_chars: 10 })
    expect(described_class.for(site, page_type: "top")).to be_truncated
  end
end
