# The aggregate limits for a site (DatabaseSchema §55). With no per-action
# approval queue, these caps and Emergency Stop are the only safety
# mechanisms, so the defaults stay conservative.
#
# Phase 1 uses monthly_budget and budget_action; the other caps have columns
# but no reader yet (Aggregate Policy is a later issue).
class SitePolicy < ApplicationRecord
  BUDGET_ACTIONS = %w[degrade stop].freeze

  belongs_to :site

  validates :monthly_budget, numericality: { greater_than: 0 }
  validates :budget_action, inclusion: { in: BUDGET_ACTIONS }
  validates :site_id, uniqueness: true

  # Phase 1 always degrades. `stop` would halt observation as well, and then
  # stale facts stop being detected while the site keeps serving them —
  # the one state this product must avoid (Technical Architecture §38).
  def degrade_only? = true
end
