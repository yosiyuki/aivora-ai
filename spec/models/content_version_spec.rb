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

  it "is read-only once grounding has been decided, and never deleted even while pending" do
    v = item.versions.create!(body: "x")
    expect { v.destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed)
    v.decide!(:passed)
    expect { v.update!(body: "edited") }.to raise_error(ActiveRecord::ReadOnlyRecord)
    expect { v.decide!(:failed) }.to raise_error(ArgumentError, /already decided/)
  end

  it "freezes its claims once decided: no additions, no edits, no deletions" do
    v = item.versions.create!(body: "x")
    claim = v.claims.create!(statement: "s", claim_kind: "general", review_status: "general")
    expect(claim).to be_grounded
    expect { claim.update!(statement: "t") }.to raise_error(ActiveRecord::ReadOnlyRecord)
    expect { claim.destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed)

    v.decide!(:passed)
    late = v.claims.build(statement: "late", claim_kind: "general", review_status: "general")
    expect(late).not_to be_valid
    expect(late.errors[:content_version]).to be_present
  end

  it "derives grounded from review_status so the two cannot disagree" do
    v = item.versions.create!(body: "x")
    blank = v.claims.create!(statement: "s", claim_kind: "verifiable", review_status: "blank", slot_key: "hours", grounded: true)
    expect(blank.reload).not_to be_grounded
    bad = v.claims.build(statement: "s", claim_kind: "verifiable", review_status: "grounded", grounded: false)
    expect(bad).not_to be_valid, "grounded status without knowledge"
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
