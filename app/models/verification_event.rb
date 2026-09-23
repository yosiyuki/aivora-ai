# One answer to a verification request (DatabaseSchema §23). Append-only: the
# owner's words are evidence and evidence is never rewritten.
#
# `person_id` is a string so the answering channel can widen later. Phase 1
# only has the admin form, so it is always "user:<id>"; a Slack integration
# would write "slack:<member id>". `experiences.person_id` has the same shape.
class VerificationEvent < ApplicationRecord
  RESULTS = %w[answered skipped].freeze
  EXTRACTION_STATUSES = %w[pending processing done failed].freeze

  belongs_to :verification_request
  belongs_to :source_item, optional: true

  validates :person_id, presence: true
  validates :result, inclusion: { in: RESULTS }
  validates :extraction_status, inclusion: { in: EXTRACTION_STATUSES }
  validates :notes, presence: true, if: -> { result == "answered" }

  before_validation { self.verified_at ||= Time.current }
  before_destroy { raise ActiveRecord::RecordNotDestroyed.new("verification events are never physically deleted", self) }

  scope :pending_extraction, -> { where(extraction_status: "pending", result: "answered") }

  # Extraction runs once per answer, enforced the same way interview turns do
  # it: a conditional update, so a second worker finds nothing to claim.
  def claim_for_extraction!
    updated = self.class.where(id: id, extraction_status: "pending").update_all(extraction_status: "processing")
    updated == 1
  end

  def self.person_id_for(user) = "user:#{user.id}"

  # Only extraction_status moves after creation; the answer itself is frozen.
  def readonly? = persisted? && !@updating_extraction

  def update_extraction!(status, source_item: nil)
    @updating_extraction = true
    update!(extraction_status: status.to_s, source_item: source_item || self.source_item)
  ensure
    @updating_extraction = false
  end
end
