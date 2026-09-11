require "rails_helper"

RSpec.describe Llm::Client do
  let(:schema) { { type: "object", properties: { kind: { type: "string" } }, required: [ "kind" ], additionalProperties: false } }

  it "resolves model, effort and max_tokens from config/llm.yml" do
    client = described_class.for(:extraction)
    expect(client.model).to eq("claude-opus-5")
    expect(client.effort).to eq(:medium)
    expect(client.max_tokens).to eq(4096)
  end

  it "rejects operations that are not in the routing table" do
    expect { described_class.for(:telepathy) }.to raise_error(ArgumentError, /config\/llm.yml/)
  end

  it "returns parsed structured output and records one llm_usage row" do
    Llm::Fake.respond(:extraction) { |call| { kind: "fact", echoed: call.messages.first[:content] } }

    result = described_class.for(:extraction).extract(system: "classify", input: "7時に開けています", schema: schema)

    expect(result).to eq("kind" => "fact", "echoed" => "7時に開けています")
    expect(LlmUsage.count).to eq(1)
    expect(LlmUsage.last).to have_attributes(operation_type: "extraction", model: "claude-opus-5", succeeded: true)
  end

  it "puts the untrusted input in the user turn, never in the system prompt" do
    Llm::Fake.respond(:extraction) { { kind: "x" } }
    described_class.for(:extraction).extract(system: "SYSTEM", input: "UNTRUSTED", schema: schema)

    call = Llm::Fake.calls.last
    expect(call.system).to eq("SYSTEM")
    expect(call.messages).to eq([ { role: :user, content: "UNTRUSTED" } ])
    expect(call.schema).to eq(schema)
    expect(call.to_h.keys).not_to include(:tools), "the adapter interface must have no way to pass tools"
  end

  it "fails loudly when no fake response is registered" do
    expect { described_class.for(:extraction).extract(system: "s", input: "i", schema: schema) }
      .to raise_error(Llm::Fake::NoResponse)
    expect(LlmUsage.last).to have_attributes(succeeded: false)
  end

  it "raises MalformedOutputError on non-JSON structured output and records the call as failed" do
    Llm::Fake.respond(:extraction) { "not json" }
    expect { described_class.for(:extraction).extract(system: "s", input: "i", schema: schema) }
      .to raise_error(Llm::MalformedOutputError)
    expect(LlmUsage.sole).to have_attributes(succeeded: false)
    expect(LlmUsage.sole.metadata).to include("error" => "malformed_output")
  end

  it "refuses to extract without a schema" do
    expect { described_class.for(:extraction).extract(system: "s", input: "i", schema: nil) }
      .to raise_error(ArgumentError, /schema/)
    expect(LlmUsage.count).to eq(0)
  end

  it "returns plain text for generate" do
    Llm::Fake.respond(:drafting) { "本文" }
    expect(described_class.for(:drafting).generate(system: "s", messages: [ { role: :user, content: "書いて" } ])).to eq("本文")
  end
end
