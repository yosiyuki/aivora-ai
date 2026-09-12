require "rails_helper"

RSpec.describe SiteArchetype, type: :model do
  let!(:site) { create_site }

  it "activates a primary archetype and mirrors it on the site" do
    record = site.add_archetype(:business, primary: true)
    expect(record).to be_is_primary
    expect(site.reload.primary_archetype).to eq("business")
    expect(site.primary_archetype_definition.archetype).to eq("business")
  end

  it "composes archetypes and keeps exactly one primary" do
    site.add_archetype(:business, primary: true)
    site.add_archetype(:media)
    expect(site.site_archetypes.count).to eq(2)
    expect(site.site_archetypes.primary.count).to eq(1)

    site.add_archetype(:media, primary: true)
    expect(site.site_archetypes.primary.pluck(:archetype)).to eq([ "media" ])
    expect(site.reload.primary_archetype).to eq("media")
    expect(site.site_archetypes.count).to eq(2), "re-adding never duplicates"
  end

  it "unions required slots across archetypes, keeping the higher weight for shared keys" do
    site.add_archetype(:business, primary: true)
    site.add_archetype(:media)

    minimum = site.required_slots(level: :minimum).map(&:key)
    expect(minimum).to contain_exactly("name", "what", "location", "topic", "audience")
    expect(site.required_slots.find { |s| s.key == "name" }.weight).to eq(1.0), "business (1.0) beats media (0.8)"
  end

  it "keeps a slot required when one archetype has it at minimum and another at a lower level" do
    shop = ArchetypeDefinition.new(archetype: "shop", label: "x", default_metric: "m", page_structure: [ "top" ],
                                   slots: [ { key: "hours", label: "h", level: "minimum", kind: "verifiable", weight: 0.5 } ])
    blog = ArchetypeDefinition.new(archetype: "blog", label: "x", default_metric: "m", page_structure: [ "top" ],
                                   slots: [ { key: "hours", label: "h", level: "enriched", kind: "verifiable", weight: 0.9 } ])
    allow(site).to receive(:archetype_definitions).and_return([ shop, blog ])

    expect(site.required_slots(level: :minimum).map(&:key)).to eq([ "hours" ])
    expect(site.required_slots.sole.weight).to eq(0.9), "without a level filter the higher weight still wins"
  end

  it "rejects archetypes that are not defined" do
    record = site.site_archetypes.build(archetype: "cathedral", activated_at: Time.current)
    expect(record).not_to be_valid
    expect(record.errors[:archetype]).to be_present
  end

  it "has no required slots before any archetype is inferred" do
    expect(site.required_slots).to be_empty
    expect(site.primary_archetype_definition).to be_nil
  end
end
