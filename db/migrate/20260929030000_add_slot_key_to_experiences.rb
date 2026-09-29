# Which archetype slot an experience answers, when it answers one — the same
# separation facts got in #36. Needed so a page can be built from the
# experiences that belong to it (services from `what`, works from `works`)
# instead of every experience the owner ever shared.
class AddSlotKeyToExperiences < ActiveRecord::Migration[8.1]
  def change
    add_column :experiences, :slot_key, :string
    add_index :experiences, [ :site_id, :slot_key ]
  end
end
