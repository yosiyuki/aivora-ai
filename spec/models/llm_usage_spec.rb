require "rails_helper"

RSpec.describe LlmUsage, type: :model do
  before { create_site }

  it "records tokens and an estimated cost from the pricing table" do
    row = described_class.record!(operation_type: :extraction, model: "claude-opus-5",
                                  usage: { input_tokens: 1_000_000, output_tokens: 100_000, cache_read_input_tokens: 200_000 })
    expect(row.site).to eq(Site.current)
    expect(row.estimated_cost).to eq(BigDecimal("5.0") + BigDecimal("2.5") + BigDecimal("0.1"))
    expect(row).to be_succeeded
  end

  it "records failures with zero cost and the error in metadata" do
    row = described_class.record!(operation_type: :extraction, model: "claude-opus-5", succeeded: false,
                                  metadata: { error: "Llm::RequestError" })
    expect(row.estimated_cost).to eq(0)
    expect(row.metadata).to eq("error" => "Llm::RequestError")
  end

  it "costs 0 for a model missing from the pricing table" do
    expect(Llm::Pricing.cost("claude-unknown", { input_tokens: 10 })).to eq(0)
    expect(Llm::Pricing).not_to be_known("claude-unknown")
  end

  it "rejects unknown operation types" do
    expect { described_class.record!(operation_type: :magic, model: "x") }.to raise_error(ActiveRecord::RecordInvalid)
  end
end
