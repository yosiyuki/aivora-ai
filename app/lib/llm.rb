# Namespace for LLM access plus the error hierarchy every caller rescues on.
module Llm
  class Error < StandardError; end

  # LLM_API_KEY is missing. Raised at call time, never at boot (§47).
  class NotConfiguredError < Error; end

  # The provider declined the request (stop_reason: refusal). The output, if
  # any, does not follow the requested schema and must not be used.
  class RefusedError < Error
    attr_reader :category, :explanation

    def initialize(category: nil, explanation: nil)
      @category = category
      @explanation = explanation
      super("LLM refused the request#{" (#{category})" if category}")
    end
  end

  # Output hit max_tokens; structured output is probably cut mid-object.
  class TruncatedError < Error; end

  # Transport / HTTP failure. `retryable?` separates 429 and 5xx from 4xx.
  class RequestError < Error
    attr_reader :retryable, :status

    def initialize(message, retryable:, status: nil)
      @retryable = retryable
      @status = status
      super(message)
    end

    def retryable? = retryable
  end

  # Structured output came back but is not valid JSON.
  class MalformedOutputError < Error; end
end
