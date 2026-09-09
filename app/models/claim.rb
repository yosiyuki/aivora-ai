# A statement in the site's own voice, classified by what it would take to
# back it (README §20). verifiable needs Knowledge; experiential rests on the
# owner's words; general is never stored as a Fact.
class Claim < ApplicationRecord
  include Versioned
  include Evidenced

  KINDS = %w[verifiable experiential general].freeze
  STATUSES = %w[candidate grounded ungrounded retired].freeze

  belongs_to :site
  belongs_to :entity, optional: true

  validates :statement, presence: true
  validates :claim_kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }
  validates :confidence, numericality: { in: 0.0..1.0 }

  def verifiable? = claim_kind == "verifiable"
  def experiential? = claim_kind == "experiential"
  def general? = claim_kind == "general"
end
