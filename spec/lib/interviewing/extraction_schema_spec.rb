require "rails_helper"

RSpec.describe Interviewing::ExtractionSchema do
  let(:schema) { described_class.build(slot_keys: %w[name what location]) }

  it "closes every object and lists required keys, as structured output demands" do
    walk = ->(node) do
      if node.is_a?(Hash)
        if node[:type] == "object"
          expect(node[:additionalProperties]).to eq(false)
          expect(node[:required]).to match_array(node[:properties].keys.map(&:to_s))
        end
        node.each_value { |v| walk.call(v) }
      elsif node.is_a?(Array)
        node.each { |v| walk.call(v) }
      end
    end
    walk.call(schema)
  end

  it "only lets the model choose from product-fixed vocabularies" do
    expect(schema.dig(:properties, :archetype, :properties, :candidates, :items, :properties, :archetype, :enum))
      .to match_array(ArchetypeDefinition.keys)
    expect(schema.dig(:properties, :facts, :items, :properties, :slot, :anyOf, 0, :enum)).to eq(%w[name what location])
    expect(schema.dig(:properties, :primary_entity, :anyOf, 0, :properties, :entity_type, :enum)).to eq(Entity::TYPES)
  end
end
