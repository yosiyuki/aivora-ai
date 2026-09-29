# The aggregate limits for a site (DatabaseSchema §55). With no per-action
# approval queue, these caps and Emergency Stop are the only safety
# mechanisms, so the defaults stay conservative.
#
# Phase 1 reads monthly_budget, budget_action and the two volume caps below;
# the redirect / link / change-ratio caps have columns but no action to bound.
class SitePolicy < ApplicationRecord
  BUDGET_ACTIONS = %w[degrade stop].freeze
  # README §32: "1 件は安全でも大量なら危険". Conservative on purpose.
  DEFAULT_MAX_NEW_PAGES_PER_WEEK = 10
  DEFAULT_MAX_PAGES_CHANGED_PER_DAY = 5

  belongs_to :site

  validates :monthly_budget, numericality: { greater_than: 0 }
  validates :budget_action, inclusion: { in: BUDGET_ACTIONS }
  validates :max_new_pages_per_week, :max_pages_changed_per_day,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :site_id, uniqueness: true

  # A NULL cap is not "no cap": a row written before the defaults existed still
  # gets the conservative value.
  def new_pages_per_week_cap = max_new_pages_per_week || DEFAULT_MAX_NEW_PAGES_PER_WEEK
  def pages_changed_per_day_cap = max_pages_changed_per_day || DEFAULT_MAX_PAGES_CHANGED_PER_DAY

  # Emergency Stop (README §34), the manual kind. Freezing stops generation
  # only: observation keeps running, or stale facts would go undetected while
  # the site kept serving them (§33). Automatic triggers wait for the traffic
  # and index data the operation phase brings.
  def frozen? = automation_frozen_at.present?
  def freeze_automation! = update!(automation_frozen_at: automation_frozen_at || Time.current)
  def resume_automation! = update!(automation_frozen_at: nil)

  # Phase 1 always degrades. `stop` would halt observation as well, and then
  # stale facts stop being detected while the site keeps serving them —
  # the one state this product must avoid (Technical Architecture §38).
  def degrade_only? = true
end
