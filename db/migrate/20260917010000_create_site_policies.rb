# The aggregate limits that stand in for per-action approval
# (DatabaseSchema §55). Phase 1 reads monthly_budget and budget_action; the
# remaining caps are created now so adding them later needs no backfill.
class CreateSitePolicies < ActiveRecord::Migration[8.1]
  def change
    create_table :site_policies do |t|
      t.references :site, null: false, foreign_key: true, index: { unique: true }

      t.integer :max_new_pages_per_week
      t.integer :max_pages_changed_per_day
      t.decimal :max_site_change_ratio, precision: 5, scale: 4
      t.integer :max_redirects_per_batch
      t.integer :max_links_changed_per_day

      # USD per calendar month, in the site's timezone.
      t.decimal :monthly_budget, precision: 10, scale: 2, null: false, default: "50.0"
      # degrade (default) | stop. Phase 1 implements degrade only: stopping
      # would stop observation too, and stale facts would go undetected (§38).
      t.string :budget_action, null: false, default: "degrade"

      t.timestamps
    end
  end
end
