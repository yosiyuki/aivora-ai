# A statement a version makes, classified by what backs it (README §20).
# grounded + non-general requires a knowledge reference; a blank is where a
# verifiable claim had no knowledge and was replaced by [[slot:key]].
class ContentClaim < ApplicationRecord
  KINDS = Claim::KINDS
  REVIEW_STATUSES = %w[grounded blank excised general].freeze
  KNOWLEDGE_TYPES = %w[Fact Experience].freeze

  belongs_to :content_version
  belongs_to :knowledge, polymorphic: true, optional: true

  validates :statement, presence: true
  validates :claim_kind, inclusion: { in: KINDS }
  validates :review_status, inclusion: { in: REVIEW_STATUSES }
  validates :knowledge_type, inclusion: { in: KNOWLEDGE_TYPES }, allow_nil: true
  validates :confidence, numericality: { in: 0.0..1.0 }
  validate :grounded_claims_have_knowledge

  scope :blanks, -> { where(review_status: "blank") }

  private

  def grounded_claims_have_knowledge
    return unless grounded? && claim_kind != "general" && knowledge.nil?

    errors.add(:knowledge, :required)
  end
end
