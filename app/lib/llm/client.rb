module Llm
  # The only way application code talks to an LLM.
  #
  #   Llm::Client.for(:extraction).extract(system:, input:, schema:)  # => Hash
  #   Llm::Client.for(:drafting).generate(system:, messages:)         # => String
  #
  # Every call, successful or not, writes one llm_usage row. `extract` takes a
  # JSON schema and returns parsed output; there is no parameter for tools.
  class Client
    attr_reader :operation, :model, :effort, :max_tokens

    def self.for(operation)
      routing = Rails.application.config.x.llm.routing
      settings = routing.fetch(:operations).fetch(operation.to_sym) do
        raise ArgumentError, "unknown LLM operation #{operation.inspect}; add it to config/llm.yml"
      end
      adapter = build_adapter(routing.fetch(:adapter), operation)
      new(operation:, adapter:, **settings.slice(:model, :effort, :max_tokens))
    end

    def self.build_adapter(name, operation)
      case name.to_s
      when "anthropic" then Anthropic.new
      when "fake" then Fake.new(operation:)
      else raise ArgumentError, "unknown LLM adapter #{name.inspect}"
      end
    end

    def initialize(operation:, adapter:, model:, effort:, max_tokens:)
      @operation = operation.to_sym
      @adapter = adapter
      @model = model.to_s
      @effort = effort.to_sym
      @max_tokens = Integer(max_tokens)
    end

    # Structured output. `input` is the untrusted text; it goes in the user
    # turn, never in the system prompt.
    def extract(system:, input:, schema:, related: nil)
      raise ArgumentError, "extract requires a JSON schema; use generate for free text" if schema.blank?

      call(system:, messages: [ { role: :user, content: input } ], schema:, related:) { |result| JSON.parse(result.text) }
    end

    def generate(system:, messages:, related: nil)
      call(system:, messages:, related:, &:text)
    end

    private

    # The usage row is written after the result has been interpreted, so a
    # response that cannot be used is never recorded as a success.
    def call(system:, messages:, related:, schema: nil)
      result = @adapter.complete(model:, max_tokens:, effort:, system:, messages:, schema:)
      check_stop_reason!(result, related)
      value = yield(result)
      LlmUsage.record!(operation_type: operation, model: result.model, usage: result.usage, related:)
      value
    rescue JSON::ParserError => e
      LlmUsage.record!(operation_type: operation, model: result.model, usage: result.usage, related:, succeeded: false,
                       metadata: { error: "malformed_output", message: e.message.to_s.first(500) })
      raise MalformedOutputError, "structured output is not valid JSON: #{e.message}"
    rescue RefusedError, TruncatedError
      raise
    rescue Error => e
      LlmUsage.record!(operation_type: operation, model:, related:, succeeded: false,
                       metadata: { error: e.class.name, message: e.message.to_s.first(500) })
      raise
    end

    def check_stop_reason!(result, related)
      case result.stop_reason
      when :refusal
        LlmUsage.record!(operation_type: operation, model: result.model, usage: result.usage, related:,
                         succeeded: false, metadata: { error: "refusal", **result.stop_details.to_h })
        raise RefusedError.new(**result.stop_details.to_h.slice(:category, :explanation))
      when :max_tokens
        LlmUsage.record!(operation_type: operation, model: result.model, usage: result.usage, related:,
                         succeeded: false, metadata: { error: "max_tokens" })
        raise TruncatedError, "output hit max_tokens (#{max_tokens}) for #{operation}"
      end
    end
  end
end
