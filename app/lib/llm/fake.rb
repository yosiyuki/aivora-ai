module Llm
  # Test double for the adapter. Specs register a response per operation; an
  # unregistered call fails loudly so a test never passes on an accidental
  # empty answer. Calls are recorded for assertions.
  class Fake
    class NoResponse < Error; end

    Call = Data.define(:model, :max_tokens, :effort, :system, :messages, :schema)

    class << self
      def responses = (@responses ||= {})
      def calls = (@calls ||= [])

      # Llm::Fake.respond(:extraction) { |call| { "kind" => "fact" } }
      # The block may return a Hash (serialised to JSON), a String, or raise.
      def respond(operation, &block)
        responses[operation.to_sym] = block
      end

      def reset!
        @responses = {}
        @calls = []
      end
    end

    def initialize(operation:)
      @operation = operation.to_sym
    end

    def complete(model:, max_tokens:, effort:, system:, messages:, schema: nil)
      call = Call.new(model:, max_tokens:, effort:, system:, messages:, schema:)
      self.class.calls << call
      handler = self.class.responses[@operation] or
        raise NoResponse, "Llm::Fake has no response registered for #{@operation}"

      body = handler.call(call)
      text = body.is_a?(String) ? body : JSON.generate(body)
      Result.new(text: text, model: model.to_s, stop_reason: :end_turn,
                 usage: { input_tokens: 0, output_tokens: 0, cache_read_input_tokens: 0, cache_creation_input_tokens: 0 })
    end
  end
end
