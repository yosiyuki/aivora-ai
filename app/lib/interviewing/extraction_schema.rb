module Interviewing
  # JSON Schema for the one structured call per answer. Enums are injected
  # from product-fixed vocabularies so the model can only choose, never
  # invent, a slot, an archetype or an entity type.
  module ExtractionSchema
    UTTERANCE_KINDS = %w[intent fact experience question problem offtopic].freeze
    ROLES = %w[expert business individual].freeze

    module_function

    def build(slot_keys:)
      archetypes = ArchetypeDefinition.keys
      {
        type: "object", additionalProperties: false,
        required: %w[role utterances primary_entity facts experiences goals archetype next_question],
        properties: {
          role: nullable(string_enum(ROLES)),
          utterances: array_of(object(
            text: { type: "string" }, kind: string_enum(UTTERANCE_KINDS), confidence: { type: "number" }
          )),
          primary_entity: nullable(object(
            name: { type: "string" }, entity_type: string_enum(Entity::TYPES), confidence: { type: "number" }
          )),
          # source_text is a verbatim span of the answer. Code checks it against
          # the raw text; anything that cannot be found there is not the user's.
          facts: array_of(object(
            slot: nullable(string_enum(slot_keys)), attribute: { type: "string" },
            value: { type: "string" }, source_text: { type: "string" }, confidence: { type: "number" }
          )),
          experiences: array_of(object(
            slot: nullable(string_enum(slot_keys)), summary: { type: "string" },
            source_text: { type: "string" }, confidence: { type: "number" }
          )),
          goals: array_of(object(statement: { type: "string" }, verb: { type: "string" }, source_text: { type: "string" }, confidence: { type: "number" })),
          archetype: object(candidates: array_of(object(archetype: string_enum(archetypes), confidence: { type: "number" }))),
          next_question: object(
            text: { type: "string" }, examples: array_of({ type: "string" }),
            targets_slot: nullable(string_enum(slot_keys)), quotes_user: { type: "boolean" }
          )
        }
      }
    end

    def object(props) = { type: "object", additionalProperties: false, required: props.keys.map(&:to_s), properties: props }
    def array_of(items) = { type: "array", items: items }
    def string_enum(values) = { type: "string", enum: values }
    def nullable(schema) = { anyOf: [ schema, { type: "null" } ] }
  end
end
