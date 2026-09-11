class CreateSourcesAndSourceItems < ActiveRecord::Migration[8.1]
  def change
    create_table :sources do |t|
      t.references :site, null: false, foreign_key: true
      t.string :source_type, null: false      # interview / website / slack / notion / sns / wordpress ...
      t.string :name, null: false
      t.string :external_id
      t.jsonb :config, null: false, default: {}
      t.string :trust_level, null: false, default: "external"   # owner / trusted / external
      t.boolean :enabled, null: false, default: true
      t.timestamps
    end
    add_index :sources, [ :site_id, :source_type ]
    # Exactly one interview source per site; Source.interview_for relies on it.
    add_index :sources, :site_id, unique: true, where: "source_type = 'interview'", name: "index_sources_one_interview_per_site"

    create_table :source_items do |t|
      t.references :source, null: false, foreign_key: true
      t.string :external_id
      t.string :source_url
      t.text :raw_content, null: false
      t.jsonb :metadata, null: false, default: {}
      t.datetime :published_at
      t.datetime :fetched_at, null: false
      t.string :checksum, null: false
      t.datetime :created_at, null: false
    end
    add_index :source_items, [ :source_id, :checksum ], unique: true
    add_index :source_items, [ :source_id, :external_id ]
  end
end
