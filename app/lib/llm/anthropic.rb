require "anthropic"

module Llm
  # Anthropic Messages API adapter. Deliberately narrow: it can send a system
  # prompt, messages, thinking/effort and a JSON schema. It has no way to send
  # tools, which is how Agent Isolation (§7) is enforced for extraction.
  class Anthropic
    FALLBACK_BETA = ::Anthropic::AnthropicBeta::SERVER_SIDE_FALLBACK_2026_07_01

    def initialize(api_key: Rails.application.config.x.llm.api_key,
                   fallbacks: Rails.application.config.x.llm.routing.fetch(:fallbacks, true))
      @api_key = api_key
      @fallbacks = fallbacks
    end

    def complete(model:, max_tokens:, effort:, system:, messages:, schema: nil)
      raise NotConfiguredError, "LLM_API_KEY is not set" if @api_key.blank?

      params = {
        model: model.to_s,
        max_tokens: max_tokens,
        system_: system,
        messages: messages,
        thinking: { type: :adaptive },
        output_config: output_config(effort, schema)
      }
      params.merge!(betas: [ FALLBACK_BETA ], fallbacks: :default) if @fallbacks

      message = client.beta.messages.create(**params)

      Result.new(
        text: message.content.find { |block| block.type == :text }&.text.to_s,
        model: message.model.to_s,
        stop_reason: message.stop_reason,
        usage: usage_hash(message.usage),
        stop_details: message.stop_details && { category: message.stop_details.category, explanation: message.stop_details.explanation }
      )
    rescue ::Anthropic::Errors::RateLimitError, ::Anthropic::Errors::InternalServerError => e
      raise RequestError.new(e.message, retryable: true, status: e.status)
    rescue ::Anthropic::Errors::APIStatusError => e
      raise RequestError.new(e.message, retryable: false, status: e.status)
    rescue ::Anthropic::Errors::APIConnectionError => e
      raise RequestError.new(e.message, retryable: true)
    end

    private

    def client
      @client ||= ::Anthropic::Client.new(api_key: @api_key)
    end

    # Structured output goes through output_config.format (json_schema). Both
    # `format` and `format_` serialise to the wire key `format`.
    def output_config(effort, schema)
      config = { effort: effort.to_sym }
      config[:format] = { type: :json_schema, schema: schema } if schema
      config
    end

    def usage_hash(usage)
      {
        input_tokens: usage.input_tokens,
        output_tokens: usage.output_tokens,
        cache_read_input_tokens: usage.cache_read_input_tokens.to_i,
        cache_creation_input_tokens: usage.cache_creation_input_tokens.to_i
      }
    end
  end
end
