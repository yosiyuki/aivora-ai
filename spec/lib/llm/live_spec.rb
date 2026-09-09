require "rails_helper"

# Runs only with LIVE_LLM=1 and LLM_API_KEY set. One real call, to catch API
# drift that the mocked specs cannot see.
RSpec.describe "Llm::Anthropic live", :live do
  it "returns schema-shaped JSON for a Japanese sentence" do
    skip "LLM_API_KEY not set" if ENV["LLM_API_KEY"].blank?

    client = Llm::Client.new(operation: :extraction, adapter: Llm::Anthropic.new(api_key: ENV["LLM_API_KEY"]),
                             model: "claude-opus-5", effort: :low, max_tokens: 512)
    schema = { type: "object",
               properties: { kind: { type: "string", enum: %w[intent fact experience] } },
               required: [ "kind" ], additionalProperties: false }
    result = client.extract(system: "Classify the user's sentence. Reply in the given JSON schema only.",
                            input: "朝7時に開けています。", schema: schema)
    expect(result["kind"]).to eq("fact")
    expect(LlmUsage.last.input_tokens).to be > 0
  end
end
