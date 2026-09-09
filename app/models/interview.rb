# The setup interview: the one interaction the product requires of a human.
# Holds conversational state only; answers also become source_items so the
# Extraction Agent treats them like any other external input (README §27.6).
class Interview < ApplicationRecord
  STATUSES = %w[in_progress ready completed abandoned].freeze
  QUESTION_CAP = 10

  belongs_to :site
  has_many :turns, -> { order(:position) }, class_name: "InterviewTurn", dependent: :destroy

  validates :status, inclusion: { in: STATUSES }

  before_validation { self.started_at ||= Time.current }

  def in_progress? = status == "in_progress"
  def completed? = status == "completed"
  def capped? = question_count >= QUESTION_CAP

  def current_turn = turns.detect { |t| !t.answered? }

  def minimum_slot_keys = site.required_slots(level: :minimum).map(&:key)
  def filled_slot_keys = slot_state.keys
  def missing_minimum_slot_keys = minimum_slot_keys - filled_slot_keys

  # Code decides readiness, never the LLM (Technical Architecture §1).
  def ready_to_generate? = minimum_slot_keys.present? && missing_minimum_slot_keys.empty?

  def fill_slot!(key, value:, source_item_id: nil, confidence: 1.0)
    update!(slot_state: slot_state.merge(key.to_s => { "value" => value, "source_item_id" => source_item_id, "confidence" => confidence }))
  end

  def complete!
    transaction do
      update!(status: "completed", completed_at: Time.current)
      site.update!(status: "active") if site.status == "setup"
    end
  end
end
