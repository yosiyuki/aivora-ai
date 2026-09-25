# A question the site needs the owner to answer (DatabaseSchema §22,
# README §14). Two origins matter in Phase 1:
#
#   initial  a blank in a generated page, or a slot no page has filled yet
#   recheck  a fact that has gone stale (#38)
#
# `entity` is accepted by the schema (README §12 asks low-confidence entity
# candidates to be confirmed) but nothing issues one yet.
class VerificationRequest < ApplicationRecord
  include NeverDeleted

  REQUEST_TYPES = %w[initial recheck entity].freeze
  STATUSES = %w[open answered closed superseded].freeze

  belongs_to :site
  belongs_to :fact, optional: true
  belongs_to :entity, optional: true
  belongs_to :content_claim, optional: true
  has_many :events, class_name: "VerificationEvent", dependent: :restrict_with_exception

  validates :request_type, inclusion: { in: REQUEST_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :question, presence: true

  scope :open, -> { where(status: "open") }
  scope :answered, -> { where(status: "answered") }
  # Highest rank first, then oldest: a question that has waited longer is asked
  # again before an equally important one raised today.
  scope :by_priority, -> { order(priority: :desc, created_at: :asc) }


  def open? = status == "open"

  # The owner answered. The answer is recorded verbatim here; turning it into
  # Knowledge happens later, in a job, so a model failure cannot lose it.
  def record_answer!(text, person_id:)
    transaction do
      event = events.create!(person_id: person_id, verified_at: Time.current, result: "answered", notes: text)
      update!(status: "answered", completed_at: Time.current)
      event
    end
  end

  # The blank this asked about is gone (the page was regenerated with the fact
  # in place, or the slot stopped being required). Nothing is deleted.
  def supersede! = update!(status: "superseded", completed_at: Time.current)

  def close! = update!(status: "closed", completed_at: Time.current)
end
