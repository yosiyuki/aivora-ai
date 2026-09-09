require "rails_helper"

RSpec.describe Llm::Anthropic do
  let(:schema) { { type: "object", properties: { kind: { type: "string" } }, required: [ "kind" ], additionalProperties: false } }
  let(:messages_api) { instance_double(Anthropic::Resources::Beta::Messages) }
  let(:sdk_client) { instance_double(Anthropic::Client, beta: instance_double(Anthropic::Resources::Beta, messages: messages_api)) }

  before { allow(Anthropic::Client).to receive(:new).with(api_key: "k").and_return(sdk_client) }

  def sdk_message(text: '{"kind":"fact"}', stop_reason: :end_turn, model: "claude-opus-5", stop_details: nil)
    usage = instance_double(Anthropic::Beta::BetaUsage, input_tokens: 120, output_tokens: 30,
                            cache_read_input_tokens: 100, cache_creation_input_tokens: nil)
    block = instance_double(Anthropic::Beta::BetaTextBlock, type: :text, text: text)
    instance_double(Anthropic::Beta::BetaMessage, content: [ block ], model: model, stop_reason: stop_reason,
                    usage: usage, stop_details: stop_details)
  end

  def complete(adapter = described_class.new(api_key: "k"), **overrides)
    adapter.complete(**{ model: "claude-opus-5", max_tokens: 4096, effort: :medium, system: "SYS",
                         messages: [ { role: :user, content: "IN" } ], schema: schema }.merge(overrides))
  end

  it "sends thinking, effort, the JSON schema and the refusal fallback, and never tools" do
    expect(messages_api).to receive(:create) do |**params|
      expect(params).to include(model: "claude-opus-5", max_tokens: 4096, system_: "SYS",
                                messages: [ { role: :user, content: "IN" } ], thinking: { type: :adaptive },
                                betas: [ :"server-side-fallback-2026-07-01" ], fallbacks: :default)
      expect(params[:output_config]).to eq(effort: :medium, format: { type: :json_schema, schema: schema })
      expect(params).not_to have_key(:tools)
      expect(params).not_to have_key(:tool_choice)
      sdk_message
    end

    result = complete
    expect(result.text).to eq('{"kind":"fact"}')
    expect(result.stop_reason).to eq(:end_turn)
    expect(result.usage).to eq(input_tokens: 120, output_tokens: 30, cache_read_input_tokens: 100, cache_creation_input_tokens: 0)
  end

  it "omits the fallback parameters when disabled and the schema when generating text" do
    expect(messages_api).to receive(:create) do |**params|
      expect(params.keys).not_to include(:betas, :fallbacks)
      expect(params[:output_config]).to eq(effort: :high)
      sdk_message(text: "本文")
    end
    complete(described_class.new(api_key: "k", fallbacks: false), effort: :high, schema: nil)
  end

  it "reports the model that actually answered, so a fallback is priced correctly" do
    allow(messages_api).to receive(:create).and_return(sdk_message(model: "claude-opus-4-8"))
    expect(complete.model).to eq("claude-opus-4-8")
  end

  it "surfaces refusals with their category" do
    details = instance_double(Anthropic::Beta::BetaRefusalStopDetails, category: :cyber, explanation: "no")
    allow(messages_api).to receive(:create).and_return(sdk_message(stop_reason: :refusal, stop_details: details))
    expect(complete.stop_details).to eq(category: :cyber, explanation: "no")
  end

  it "maps 429 / 5xx to retryable and other 4xx to non-retryable RequestError" do
    allow(messages_api).to receive(:create).and_raise(Anthropic::Errors::APIStatusError.for(url: "u", status: 429, headers: {}, body: nil, request: nil, response: nil, message: "slow down"))
    expect { complete }.to raise_error(Llm::RequestError) { |e| expect(e).to be_retryable; expect(e.status).to eq(429) }

    allow(messages_api).to receive(:create).and_raise(Anthropic::Errors::APIStatusError.for(url: "u", status: 400, headers: {}, body: nil, request: nil, response: nil, message: "bad"))
    expect { complete }.to raise_error(Llm::RequestError) { |e| expect(e).not_to be_retryable }
  end

  it "raises NotConfiguredError at call time when the key is missing, without touching the network" do
    expect(Anthropic::Client).not_to receive(:new).with(api_key: nil)
    expect { complete(described_class.new(api_key: nil)) }.to raise_error(Llm::NotConfiguredError, /LLM_API_KEY/)
  end
end
