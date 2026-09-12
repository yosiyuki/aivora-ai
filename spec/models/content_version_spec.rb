require "rails_helper"

RSpec.describe ContentVersion, type: :model do
  let!(:site) { create_site }
  let(:item) { site.content_items.create!(archetype_page_type: "top", url: "/") }

  it "numbers versions automatically and finds blanks in the body" do
    v = item.versions.create!(body: "営業時間は [[slot:hours]] です。場所は [[slot:location]]、また [[slot:hours]]。")
    expect(v.version).to eq(1)
    expect(item.versions.create!(body: "x").version).to eq(2)
    expect(v.blank_slot_keys).to eq(%w[hours location])
  end

  it "is read-only once grounding has been decided" do
    v = item.versions.create!(body: "x")
    v.update!(grounding_status: "passed")
    expect { v.update!(body: "edited") }.to raise_error(ActiveRecord::ReadOnlyRecord)
    expect { v.destroy! }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  it "requires knowledge on grounded non-general claims and records blanks with a slot" do
    v = item.versions.create!(body: "x")
    expect(v.claims.build(statement: "s", claim_kind: "verifiable", grounded: true, review_status: "grounded")).not_to be_valid
    expect(v.claims.build(statement: "s", claim_kind: "general", grounded: true, review_status: "general")).to be_valid

    entity = site.entities.create!(entity_type: "business", canonical_name: "店")
    fact = entity.facts.create!(attribute_key: "hours", value_json: { "value" => "7-17" }, confidence: 0.9)
    expect(v.claims.build(statement: "s", claim_kind: "verifiable", grounded: true, review_status: "grounded", knowledge: fact)).to be_valid

    blank = v.claims.create!(statement: "営業時間は9時から", claim_kind: "verifiable", review_status: "blank", slot_key: "hours")
    expect(v.blanks).to eq([ blank ])
    expect(v.claims.build(statement: "s", claim_kind: "verifiable", review_status: "grounded", knowledge_type: "Site", knowledge_id: 1)).not_to be_valid
  end
end
