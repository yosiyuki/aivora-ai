# README §32: with no per-action review, these caps are one of the two safety
# mechanisms, so a site never runs without them. Conservative defaults; the
# other three caps stay nullable until an action exists for them to bound.
class DefaultAggregateCapsOnSitePolicies < ActiveRecord::Migration[8.1]
  def up
    change_column_default :site_policies, :max_new_pages_per_week, from: nil, to: 10
    change_column_default :site_policies, :max_pages_changed_per_day, from: nil, to: 5
    execute "UPDATE site_policies SET max_new_pages_per_week = 10 WHERE max_new_pages_per_week IS NULL"
    execute "UPDATE site_policies SET max_pages_changed_per_day = 5 WHERE max_pages_changed_per_day IS NULL"
  end

  def down
    change_column_default :site_policies, :max_new_pages_per_week, from: 10, to: nil
    change_column_default :site_policies, :max_pages_changed_per_day, from: 5, to: nil
  end
end
