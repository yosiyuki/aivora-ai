# Content layer (DatabaseSchema §27-§29): generated pages, their versions and
# the claims each version makes. URLs never change once issued; versions are
# only ever appended; only a version that passed grounding can be published.
class CreateContentLayer < ActiveRecord::Migration[8.1]
  def change
    create_table :content_items do |t|
      t.references :site, null: false, foreign_key: true
      t.string :content_type, null: false, default: "page"          # page / article
      t.string :archetype_page_type, null: false                     # top / services / faq / news / articles / article ...
      t.string :url, null: false                                     # immutable once issued
      t.string :canonical_url
      t.string :language, null: false
      t.string :title
      t.string :status, null: false, default: "draft"                # draft / generating / published / unpublished
      t.bigint :published_version_id                                 # FK added below (circular)
      t.datetime :published_at
      t.timestamps
    end
    add_index :content_items, [ :site_id, :url ], unique: true
    add_index :content_items, [ :site_id, :archetype_page_type ]

    create_table :content_versions do |t|
      t.references :content_item, null: false, foreign_key: true
      t.integer :version, null: false
      t.string :title
      t.text :body, null: false                                      # Markdown; may contain [[slot:key]]
      t.jsonb :metadata, null: false, default: {}                    # knowledge pack refs / llm_usage ids / blanks / error
      t.string :source, null: false, default: "generated"            # generated / regenerated
      t.string :grounding_status, null: false, default: "pending"    # pending / passed / failed
      t.datetime :created_at, null: false
    end
    add_index :content_versions, [ :content_item_id, :version ], unique: true
    add_foreign_key :content_items, :content_versions, column: :published_version_id

    create_table :content_claims do |t|
      t.references :content_version, null: false, foreign_key: true
      t.text :statement, null: false
      t.integer :start_offset
      t.integer :end_offset
      t.string :claim_kind, null: false                              # verifiable / experiential / general
      t.string :knowledge_type                                       # Fact / Experience
      t.bigint :knowledge_id
      t.string :slot_key
      t.boolean :grounded, null: false, default: false
      t.float :confidence, null: false, default: 0
      t.string :review_status, null: false                           # grounded / blank / excised / general
      t.datetime :created_at, null: false
    end
    add_index :content_claims, [ :content_version_id, :review_status ]
    add_index :content_claims, [ :knowledge_type, :knowledge_id ]
  end
end
