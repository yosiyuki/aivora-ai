class InterviewTurn < ApplicationRecord
  belongs_to :interview
  belongs_to :source_item, optional: true

  validates :question_text, presence: true
  validates :question_kind, presence: true
  validates :examples, length: { is: 3, message: :three_examples }
  validates :position, presence: true, uniqueness: { scope: :interview_id }

  EXTRACTION_STATUSES = %w[pending processing done failed skipped].freeze

  # pending -> processing exactly once, at the database. Returns false when
  # another request already claimed this turn or it already reached a
  # terminal state, so the same answer never triggers a second LLM call.
  def claim_for_extraction!
    claimed = self.class.where(id: id, extraction_status: "pending").update_all(extraction_status: "processing") == 1
    reload if claimed
    claimed
  end
  validates :extraction_status, inclusion: { in: EXTRACTION_STATUSES }

  def answered? = answered_at.present?
  def extracted? = extraction_status == "done"
end
