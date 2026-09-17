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

    # True when the month's budget sent this call to a smaller model.
    def degraded? = @degraded

    def self.for(operation, site: Site.current)
      routing = Rails.application.config.x.llm.routing
      settings = routing.fetch(:operations).fetch(operation.to_sym) do
        raise ArgumentError, "unknown LLM operation #{operation.inspect}; add it to config/llm.yml"
      end
      adapter = build_adapter(routing.fetch(:adapter), operation)
      new(operation:, adapter:, **settings.slice(:model, :effort, :max_tokens),
          degraded_model: settings[:degraded_model], budget: Budget.for(site))
    end

    def self.build_adapter(name, operation)
      case name.to_s
      when "anthropic" then Anthropic.new
      when "fake" then Fake.new(operation:)
      else raise ArgumentError, "unknown LLM adapter #{name.inspect}"
      end
    end

    def initialize(operation:, adapter:, model:, effort:, max_tokens:, degraded_model: nil, budget: Budget.none)
      @operation = operation.to_sym
      @adapter = adapter
      @effort = effort.to_sym
      @max_tokens = Integer(max_tokens)

      # Which model this call uses is decided here, once, from configuration.
      # An operation with no degraded_model keeps its primary model: running
      # it is still cheaper than the cost of not running it.
      @degraded = budget.degraded? && degraded_model.present?
      @model = (@degraded ? degraded_model : model).to_s
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
      LlmUsage.record!(operation_type: operation, model: result.model, usage: result.usage, related:, metadata: usage_metadata)
      value
    rescue JSON::ParserError => e
      LlmUsage.record!(operation_type: operation, model: result.model, usage: result.usage, related:, succeeded: false,
                       metadata: usage_metadata(error: "malformed_output", message: e.message.to_s.first(500)))
      raise MalformedOutputError, "structured output is not valid JSON: #{e.message}"
    rescue RefusedError, TruncatedError
      raise
    rescue Error => e
      LlmUsage.record!(operation_type: operation, model:, related:, succeeded: false,
                       metadata: usage_metadata(error: e.class.name, message: e.message.to_s.first(500)))
      raise
    end

    # The model column alone cannot say why a smaller model was used: a routing
    # change looks identical. Recording the flag keeps an overrun month
    # explainable afterwards.
    def usage_metadata(**extra)
      degraded? ? extra.merge(degraded: true) : extra
    end

    def check_stop_reason!(result, related)
      case result.stop_reason
      when :refusal
        LlmUsage.record!(operation_type: operation, model: result.model, usage: result.usage, related:,
                         succeeded: false, metadata: usage_metadata(error: "refusal", **result.stop_details.to_h))
        raise RefusedError.new(**result.stop_details.to_h.slice(:category, :explanation))
      when :max_tokens
        LlmUsage.record!(operation_type: operation, model: result.model, usage: result.usage, related:,
                         succeeded: false, metadata: usage_metadata(error: "max_tokens"))
        raise TruncatedError, "output hit max_tokens (#{max_tokens}) for #{operation}"
      end
    end
  end
end
