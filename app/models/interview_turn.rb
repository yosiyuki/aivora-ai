class InterviewTurn < ApplicationRecord
  belongs_to :interview
  belongs_to :source_item, optional: true

  validates :question_text, presence: true
  validates :question_kind, presence: true
  validates :examples, length: { is: 3, message: :three_examples }
  validates :position, presence: true, uniqueness: { scope: :interview_id }

  EXTRACTION_STATUSES = %w[pending done failed skipped].freeze
  validates :extraction_status, inclusion: { in: EXTRACTION_STATUSES }

  def answered? = answered_at.present?
  def extracted? = extraction_status == "done"
end
