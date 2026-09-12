require "rails_helper"

RSpec.describe Fact, type: :model do
  let!(:site) { create_site }
  let(:entity) { site.entities.create!(entity_type: "business", canonical_name: "渋谷のカフェ") }

  it "cannot be accepted without evidence" do
    fact = entity.facts.build(attribute_key: "opening_hours", value_json: { "value" => "07:00-17:00" }, status: "accepted", confidence: 0.9)
    expect(fact).not_to be_valid
    expect(fact.errors[:status]).to include(I18n.t("activerecord.errors.models.fact.attributes.status.needs_provenance"))
  end

  it "is accepted through accept!, which links evidence and stamps verification" do
    fact = entity.facts.create!(attribute_key: "opening_hours", value_json: { "value" => "07:00-17:00" }, confidence: 0.9)
    expect(fact.status).to eq("candidate")

    fact.accept!(evidence: owner_evidence)
    expect(fact.reload).to be_accepted
    expect(fact.last_verified_at).to be_present
    expect(fact).to be_provenanced
    expect(fact.evidence.first).to be_owner
    expect(fact.value).to eq("07:00-17:00")
  end

  it "versions every change and keeps the old evidence when superseded" do
    fact = entity.facts.create!(attribute_key: "opening_hours", value_json: { "value" => "07:00-17:00" }, confidence: 0.9)
    fact.accept!(evidence: owner_evidence(text: "7時から"))
    expect(fact.knowledge_versions.pluck(:version, :change_reason)).to eq([ [ 1, "created" ], [ 2, "accepted" ] ])

    newer = fact.supersede!({ "value" => "08:00-17:00" }, evidence: owner_evidence(text: "8時に変えました"))
    expect(fact.reload.status).to eq("retired")
    expect(fact.valid_until).to be_present
    expect(fact.evidence.count).to eq(1), "old evidence is retained"
    expect(newer).to be_accepted
    expect(newer.knowledge_versions.last.change_reason).to eq("accepted")
    expect(Fact.current).to eq([ newer ])
    expect(Fact.count).to eq(2), "nothing is deleted"
  end
  it "cannot be flipped to accepted around accept!, even with evidence linked" do
    fact = entity.facts.create!(attribute_key: "opening_hours", value_json: { "value" => "07:00" }, confidence: 0.9)
    fact.add_evidence!(owner_evidence)
    fact.status = "accepted"
    expect(fact).not_to be_valid
    expect(fact.errors[:status]).to include(I18n.t("activerecord.errors.models.fact.attributes.status.use_accept"))
    expect(fact.last_verified_at).to be_nil
  end

  it "is never physically deleted" do
    fact = entity.facts.create!(attribute_key: "opening_hours", value_json: { "value" => "07:00" }, confidence: 0.9)
    expect { fact.destroy! }.to raise_error(ActiveRecord::DeleteRestrictionError)
    expect(Fact.exists?(fact.id)).to be(true)
  end
end
