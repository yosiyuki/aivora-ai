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
  validate :parent_version_still_pending, on: :create

  # `grounded` is derived from review_status; the two can never disagree.
  before_validation { self.grounded = %w[grounded general].include?(review_status) }
  before_destroy { raise ActiveRecord::RecordNotDestroyed.new("content claims are never physically deleted", self) }

  scope :blanks, -> { where(review_status: "blank") }

  # Append-only: a claim is written once, while its version is still pending.
  def readonly? = persisted?

  private

  def grounded_claims_have_knowledge
    return unless review_status == "grounded" && claim_kind != "general" && knowledge.nil?

    errors.add(:knowledge, :required)
  end

  def parent_version_still_pending
    errors.add(:content_version, :decided) if content_version&.decided?
  end
end
