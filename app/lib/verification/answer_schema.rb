module Verification
  # Structured output for one verification answer. Narrower than the interview
  # schema on purpose: this asks about one slot, so the model reports a value
  # for that slot and nothing else. No archetype, no next question, no entity.
  module AnswerSchema
    module_function

    def build(slot_key:)
      {
        type: "object", additionalProperties: false,
        required: %w[answered value source_text confidence],
        properties: {
          # The owner may reply without actually answering ("I'll check").
          answered: { type: "boolean" },
          value: { anyOf: [ { type: "string" }, { type: "null" } ] },
          # A verbatim span of the reply. Code checks it against the raw text;
          # anything not found there is not the owner's word.
          source_text: { anyOf: [ { type: "string" }, { type: "null" } ] },
          confidence: { type: "number" },
          slot: { type: "string", enum: [ slot_key.to_s ] }
        }
      }
    end
  end
end
