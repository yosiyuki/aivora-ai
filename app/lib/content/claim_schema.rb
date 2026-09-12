module Content
  # Structured output for the grounding pass: one claim per statement, with
  # kind and a reference into the knowledge pack. Offsets are not asked for;
  # code locates each statement in the body.
  module ClaimSchema
    module_function

    def build(slot_keys:)
      {
        type: "object", additionalProperties: false, required: [ "claims" ],
        properties: {
          claims: {
            type: "array",
            items: {
              type: "object", additionalProperties: false,
              required: %w[statement kind support slot_key confidence],
              properties: {
                statement: { type: "string" },
                kind: { type: "string", enum: ContentClaim::KINDS },
                support: { anyOf: [ { type: "object", additionalProperties: false, required: [ "ref" ], properties: { ref: { type: "string" } } },
                                    { type: "null" } ] },
                slot_key: { anyOf: [ { type: "string", enum: slot_keys }, { type: "null" } ] },
                confidence: { type: "number" }
              }
            }
          }
        }
      }
    end
  end
end
