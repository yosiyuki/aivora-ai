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

  describe "slot keys" do
    it "separates the extraction's wording from the slot it answers" do
      site = cafe_site
      fact = site.primary_entity.facts.create!(attribute_key: "主な読者", slot_key: "audience",
                                               value_json: { "value" => "初めて来る人" }, confidence: 0.9)

      expect(fact.attribute_key).to eq("主な読者"), "the owner's own wording survives"
      expect(described_class.for_slot("audience")).to include(fact)
    end

    it "only fills a slot once the fact is accepted" do
      site = cafe_site
      fact = site.primary_entity.facts.create!(attribute_key: "主な読者", slot_key: "audience",
                                               value_json: { "value" => "初めて来る人" }, confidence: 0.9)

      expect(fact).not_to be_fills_slot, "a candidate is the model's word, not the owner's"

      fact.accept!(evidence: owner_evidence(site, text: "初めて来る人に読んでほしい"))

      expect(fact.reload).to be_fills_slot
    end

    it "is nil for a fact that answers no slot" do
      site = cafe_site
      fact = site.primary_entity.facts.create!(attribute_key: "お土産の探し方", value_json: { "value" => "カフェの雑貨" }, confidence: 0.9)

      expect(fact.slot_key).to be_nil
      expect(fact).not_to be_fills_slot
    end

    it "carries the slot forward when superseded, so the replacement still fills it" do
      site = cafe_site
      fact = site.primary_entity.facts.for_slot("location").first

      replacement = fact.supersede!({ "value" => "神泉" }, evidence: owner_evidence(site, text: "神泉に移転しました"))

      expect(replacement.slot_key).to eq("location")
      expect(replacement).to be_fills_slot
      expect(fact.reload.status).to eq("retired")
    end
  end

  describe "#mark_stale!" do
    it "stops publication without claiming the value is wrong" do
      site = cafe_site
      fact = site.primary_entity.facts.for_slot("location").first

      fact.mark_stale!

      expect(fact.reload.status).to eq("stale")
      expect(fact.valid_until).to be_nil, "unchecked is not retired"
      expect(fact.value).to eq("渋谷"), "the value is kept for the owner to confirm"
    end

    it "keeps a stale fact out of what a page may say" do
      site = cafe_site
      fact = site.primary_entity.facts.for_slot("location").first

      fact.mark_stale!

      expect(described_class.current).not_to include(fact)
    end

    it "only applies to a fact that was published in the first place" do
      site = cafe_site
      candidate = site.primary_entity.facts.create!(attribute_key: "営業時間", slot_key: "hours",
                                                    value_json: { "value" => "7時-17時" }, confidence: 0.9)

      expect(candidate.mark_stale!).to be(false)
      expect(candidate.reload.status).to eq("candidate")
    end

    it "is reversed by accepting it again" do
      site = cafe_site
      fact = site.primary_entity.facts.for_slot("location").first
      fact.mark_stale!

      fact.accept!(evidence: owner_evidence(site, text: "いまも渋谷です"))

      expect(fact.reload.status).to eq("accepted")
      expect(fact.last_verified_at).to be_within(5.seconds).of(Time.current)
    end
  end
end
