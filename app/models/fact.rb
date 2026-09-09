# A structured, temporal, provenanced statement about an entity
# (DatabaseSchema §12; README §13). A fact cannot be accepted without
# evidence, and every change is versioned.
class Fact < ApplicationRecord
  include Versioned
  include Evidenced

  RISK_LEVELS = %w[low medium high].freeze
  STATUSES = %w[candidate accepted stale retired].freeze

  belongs_to :site
  belongs_to :entity

  validates :attribute_key, presence: true
  validates :risk_level, inclusion: { in: RISK_LEVELS }
  validates :status, inclusion: { in: STATUSES }
  validates :confidence, numericality: { in: 0.0..1.0 }
  validate :accepted_facts_need_provenance

  before_validation { self.site ||= entity&.site }
  before_validation { self.valid_from ||= Time.current }

  scope :current, -> { where(status: "accepted").where("valid_until IS NULL OR valid_until > ?", Time.current) }

  def accepted? = status == "accepted"
  def value = value_json.is_a?(Hash) && value_json.key?("value") ? value_json["value"] : value_json

  # Validation happens here, in code: the caller decides the evidence is good
  # enough (e.g. the owner said it), the model only records that decision.
  def accept!(evidence:, verified_at: Time.current, changed_by: nil)
    transaction do
      add_evidence!(evidence)
      self.changed_by = changed_by
      self.change_reason = "accepted"
      update!(status: "accepted", last_verified_at: verified_at)
    end
  end

  # Nothing is deleted: superseding a fact closes its validity window.
  def supersede!(new_value_json, evidence:, changed_by: nil)
    transaction do
      self.changed_by = changed_by
      self.change_reason = "superseded"
      update!(valid_until: Time.current, status: "retired")
      entity.facts.create!(site:, attribute_key:, unit:, risk_level:, value_json: new_value_json, confidence:,
                           status: "candidate", changed_by: changed_by, change_reason: "supersedes fact #{id}")
                  .tap { |f| f.accept!(evidence: evidence, changed_by: changed_by) }
    end
  end

  private

  def accepted_facts_need_provenance
    return unless accepted?
    return if persisted? && evidence_links.exists?

    errors.add(:status, :needs_provenance) unless evidence_links.any?
  end
end
