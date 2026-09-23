module Verification
  # One structured call per answer. Agent Isolation applies unchanged: the
  # owner's reply is untrusted input, it goes in the user turn, and the client
  # has no tools parameter to give this agent.
  class AnswerAgent
    PROMPT = Rails.root.join("app/prompts/verification/answer.txt")

    def initialize(request, client: Llm::Client.for(:extraction))
      @request = request
      @client = client
    end

    def call(event)
      @client.extract(system: system_prompt, input: event.notes.to_s,
                      schema: AnswerSchema.build(slot_key: @request.slot_key),
                      related: event.source_item)
    end

    private

    def system_prompt
      slot = @request.site.required_slots.find { |s| s.key == @request.slot_key }
      PROMPT.read
            .sub("{{QUESTION}}", @request.question.to_s)
            .sub("{{SLOT_LABEL}}", slot&.label.to_s)
            .sub("{{SLOT_KEY}}", @request.slot_key.to_s)
    end
  end
end
