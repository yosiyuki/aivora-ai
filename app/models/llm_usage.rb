# One row per LLM API call, success or failure. This is control data, not
# telemetry: the monthly budget (#7) and model routing decisions read it.
class LlmUsage < ApplicationRecord
  self.table_name = "llm_usage"

  OPERATION_TYPES = %w[extraction entity_resolution planning drafting grounding].freeze

  belongs_to :site, optional: true
  belongs_to :related, polymorphic: true, optional: true

  validates :operation_type, inclusion: { in: OPERATION_TYPES }
  validates :model, presence: true

  scope :this_month, -> { where(created_at: Time.current.all_month) }
  scope :succeeded, -> { where(succeeded: true) }

  def self.record!(operation_type:, model:, usage: nil, related: nil, succeeded: true, metadata: {})
    tokens = usage.to_h
    # An unlisted model (rename, unexpected fallback) must not look like a free call.
    metadata = metadata.merge("pricing_unknown" => true) unless Llm::Pricing.known?(model)
    create!(
      site: Site.current,
      operation_type: operation_type.to_s,
      model: model.to_s,
      input_tokens: tokens.fetch(:input_tokens, 0),
      output_tokens: tokens.fetch(:output_tokens, 0),
      cache_read_input_tokens: tokens.fetch(:cache_read_input_tokens, 0),
      cache_creation_input_tokens: tokens.fetch(:cache_creation_input_tokens, 0),
      estimated_cost: Llm::Pricing.cost(model, tokens),
      related: related,
      succeeded: succeeded,
      metadata: metadata
    )
  end
end
