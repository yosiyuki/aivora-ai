module Llm
  # Fills llm_usage.estimated_cost from config/llm_pricing.yml. Unknown models
  # cost 0 and are flagged so the gap is visible instead of silently wrong.
  module Pricing
    PER_MILLION = 1_000_000.0

    def self.rates(model)
      table = Rails.application.config.x.llm.pricing
      table[model.to_s.to_sym] || table[model.to_s]
    end

    def self.known?(model) = rates(model).present?

    def self.cost(model, tokens)
      r = rates(model)
      return 0 unless r

      t = tokens.to_h
      ((t.fetch(:input_tokens, 0) * r[:input]) +
       (t.fetch(:output_tokens, 0) * r[:output]) +
       (t.fetch(:cache_read_input_tokens, 0) * r.fetch(:cache_read, 0)) +
       (t.fetch(:cache_creation_input_tokens, 0) * r.fetch(:cache_write, 0))) / PER_MILLION
    end
  end
end
