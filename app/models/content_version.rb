# One generation of a page's text (DatabaseSchema §28). Versions are appended,
# never rewritten: once grounding has been decided the row is read-only.
class ContentVersion < ApplicationRecord
  GROUNDING_STATUSES = %w[pending passed failed].freeze
  SOURCES = %w[generated regenerated].freeze
  BLANK_PATTERN = /\[\[slot:([a-z_]+)\]\]/

  belongs_to :content_item
  has_many :claims, class_name: "ContentClaim", dependent: :restrict_with_exception

  validates :version, presence: true, uniqueness: { scope: :content_item_id }
  validates :body, presence: true
  validates :grounding_status, inclusion: { in: GROUNDING_STATUSES }
  validates :source, inclusion: { in: SOURCES }

  before_validation { self.version ||= content_item&.next_version_number }
  before_destroy { raise ActiveRecord::RecordNotDestroyed.new("content versions are never physically deleted", self) }

  def passed? = grounding_status == "passed"
  def failed? = grounding_status == "failed"
  def pending? = grounding_status == "pending"
  def decided? = !pending?
  def blanks = claims.where(review_status: "blank")
  def blank_slot_keys = body.scan(BLANK_PATTERN).flatten.uniq

  # Once grounding is decided the version is frozen, claims included.
  def readonly? = persisted? && grounding_status_was != "pending"

  def decide!(status)
    raise ArgumentError, "grounding already decided" if decided?

    update!(grounding_status: status.to_s)
  end
end
