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
    expect(pack.missing_slots.map(&:key)).to include("hours", "name", "what")
    expect(pack.missing_slots.map(&:key)).not_to include("location"), "an accepted fact fills its slot"
    expect(pack.to_prompt).to include("F1: location = 渋谷").and include("E1: 自家焙煎").and include("hours=営業時間")
  end

  it "only includes accepted, current facts" do
    entity = site.primary_entity
    entity.facts.create!(attribute_key: "hours", value_json: { "value" => "7-17" }, confidence: 0.5)   # candidate
    expect(described_class.for(site, page_type: "top").facts.map(&:attribute_key)).to eq([ "location" ])
  end

  it "marks the pack truncated when experiences exceed the body budget" do
    stub_const("Content::KnowledgePack::LIMITS", { facts: 200, experiences: 50, body_chars: 10 })
    expect(described_class.for(site, page_type: "top")).to be_truncated
  end
end
