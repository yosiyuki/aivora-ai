# Emergency Stop, manual form (README §34). A timestamp rather than a flag so
# the dashboard can say since when. Only generation honours it: observation
# (staleness, verification answers) keeps running by design (§33).
class AddAutomationFrozenAtToSitePolicies < ActiveRecord::Migration[8.1]
  def change
    add_column :site_policies, :automation_frozen_at, :datetime
  end
end
