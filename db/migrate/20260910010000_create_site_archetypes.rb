class CreateSiteArchetypes < ActiveRecord::Migration[8.1]
  def change
    create_table :site_archetypes do |t|
      t.references :site, null: false, foreign_key: true
      t.string :archetype, null: false
      t.boolean :is_primary, null: false, default: false
      t.datetime :activated_at, null: false
      t.timestamps
    end
    add_index :site_archetypes, [ :site_id, :archetype ], unique: true
    add_index :site_archetypes, [ :site_id ], unique: true, where: "is_primary", name: "index_site_archetypes_one_primary_per_site"
  end
end
