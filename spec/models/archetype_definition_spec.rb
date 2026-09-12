require "rails_helper"

RSpec.describe ArchetypeDefinition do
  it "loads the four product-fixed archetypes from config/archetypes" do
    expect(described_class.keys).to contain_exactly("business", "media", "knowledge_base", "portfolio")
  end

  it "exposes page structure and levelled slots for business" do
    business = described_class.find(:business)
    expect(business.page_structure).to eq(%w[top services faq news])
    expect(business.minimum_slots.map(&:key)).to eq(%w[name what location])
    expect(business.slots(level: :standard).map(&:key)).to eq(%w[hours contact offerings])
    expect(business.slots.size).to eq(8)
    expect(business.slot(:hours)).to have_attributes(level: "standard", kind: "verifiable", weight: 0.9)
    expect(business.default_metric).to eq("visits_or_inquiries")
  end

  it "weights the same slot differently per archetype: hours matter for a shop, not for a blog" do
    expect(described_class.find(:business).slot(:hours)).to be_present
    expect(described_class.find(:media).slot(:hours)).to be_nil
  end

  it "is validated at boot by the initializer, not lazily" do
    expect(Rails.root.join("config/initializers/archetype_definitions.rb").read).to include("ArchetypeDefinition.all")
  end

  it "raises for an unknown archetype" do
    expect { described_class.find(:cathedral) }.to raise_error(ArgumentError, /unknown archetype/)
  end

  it "rejects malformed definitions at load time" do
    bad = { archetype: "x", label: "x", default_metric: "m", page_structure: [ "top" ],
            slots: [ { key: "a", label: "A", level: "minimum", kind: "verifiable", weight: 1 },
                     { key: "a", label: "A2", level: "standard", kind: "verifiable", weight: 1 } ] }
    expect { described_class.new(**bad).validate! }.to raise_error(ArgumentError, /unique/)

    bad[:slots] = [ { key: "a", label: "A", level: "sometimes", kind: "verifiable", weight: 1 } ]
    expect { described_class.new(**bad).validate! }.to raise_error(ArgumentError, /level/)

    bad[:slots] = [ { key: "a", label: "A", level: "standard", kind: "verifiable", weight: 1 } ]
    expect { described_class.new(**bad).validate! }.to raise_error(ArgumentError, /minimum/)
  end
end
