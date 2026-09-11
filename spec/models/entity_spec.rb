require "rails_helper"

RSpec.describe Entity, type: :model do
  let!(:site) { create_site }

  it "gives Japanese names a stable slug and keeps slugs unique per site" do
    a = site.entities.create!(entity_type: "business", canonical_name: "渋谷のカフェ")
    b = site.entities.create!(entity_type: "business", canonical_name: "渋谷のカフェ 2号店")
    expect(a.slug).to eq("entity")
    expect(b.slug).to eq("entity-2")
    expect(site.entities.create!(entity_type: "person", canonical_name: "Taro Yamada").slug).to eq("taro-yamada")
  end

  it "collects aliases and records versions" do
    e = site.entities.create!(entity_type: "business", canonical_name: "Cafe ABC")
    e.add_alias!("ABC Coffee", source: "interview", confidence: 0.8)
    e.add_alias!("ABC Coffee")
    expect(e.entity_aliases.count).to eq(1)
    expect(e.knowledge_versions.count).to eq(1)
  end

  it "promotes a candidate into an entity exactly once" do
    item = owner_source_item
    candidate = site.entity_candidates.create!(candidate_name: "渋谷のカフェ", entity_type: "business", source_item: item, confidence: 0.9)
    entity = candidate.promote!
    expect(candidate.reload.status).to eq("accepted")
    expect(candidate.proposed_entity).to eq(entity)
    expect(entity.knowledge_versions.first.change_reason).to match(/promoted from candidate/)

    again = site.entity_candidates.create!(candidate_name: "渋谷のカフェ", entity_type: "business", confidence: 0.5)
    expect(again.promote!).to eq(entity), "same name and type resolves to the existing entity"
    expect(site.entities.count).to eq(1)
    expect(candidate.promote!).to eq(entity), "promoting an accepted candidate again is a no-op"

    rejected = site.entity_candidates.create!(candidate_name: "別の店", entity_type: "business", confidence: 0.5)
    rejected.reject!
    expect { rejected.promote! }.to raise_error(ArgumentError, /rejected/)
    expect(rejected.reload.status).to eq("rejected")
  end

  it "enforces one entity per (site, type, name) at the database" do
    site.entities.create!(entity_type: "business", canonical_name: "渋谷のカフェ")
    expect { site.entities.create!(entity_type: "business", canonical_name: "渋谷のカフェ") }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
