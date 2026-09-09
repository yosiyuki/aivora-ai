require "rails_helper"

RSpec.describe Evidence, type: :model do
  let!(:site) { create_site }

  it "is cut from a source item and inherits its trust and site" do
    item = owner_source_item(text: "豆は農園から直接仕入れています")
    ev = Evidence.from_source_item!(item, content: "豆は農園から直接仕入れています", evidence_type: "quote")
    expect(ev.site).to eq(site)
    expect(ev.trust_level).to eq("owner")
    expect(ev.observed_at).to eq(item.fetched_at)
  end

  it "links to several kinds of knowledge and dedupes links" do
    ev = owner_evidence(text: "静かで落ち着ける店です")
    experience = site.experiences.create!(summary: "静かで落ち着ける", body: "静かで落ち着ける店です")
    claim = site.claims.create!(statement: "静かで落ち着ける店", claim_kind: "experiential", confidence: 0.8)
    experience.add_evidence!(ev)
    experience.add_evidence!(ev)
    claim.add_evidence!(ev)
    expect(ev.evidence_links.count).to eq(2)
    expect(experience.evidence).to eq([ ev ])
    expect(claim).to be_experiential
  end

  it "keeps the owner's words on an experience" do
    exp = site.experiences.create!(summary: "豆へのこだわり", body: "豆は農園から直接仕入れて、自分で焙煎しています")
    expect(exp.body).to include("自分で焙煎")
    expect(exp.knowledge_versions.count).to eq(1)
  end

  it "rejects claim kinds outside the vocabulary" do
    expect(site.claims.build(statement: "x", claim_kind: "rumour")).not_to be_valid
  end
end
