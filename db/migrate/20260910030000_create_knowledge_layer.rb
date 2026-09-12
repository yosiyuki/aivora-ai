# Minimum Knowledge layer for the main path (DatabaseSchema §6, §8-§10, §12-§13,
# §16-§20). Everything carries site_id; nothing is ever physically deleted.
class CreateKnowledgeLayer < ActiveRecord::Migration[8.1]
  def change
    create_table :evidence do |t|
      t.references :site, null: false, foreign_key: true
      t.references :source_item, null: false, foreign_key: true
      t.string :evidence_type, null: false          # statement / quote / document / observation
      t.text :content, null: false
      t.jsonb :metadata, null: false, default: {}
      t.datetime :observed_at, null: false
      t.string :trust_level, null: false            # copied from the source at creation
      t.datetime :created_at, null: false
    end

    create_table :entities do |t|
      t.references :site, null: false, foreign_key: true
      t.string :entity_type, null: false            # business / person / topic / project / place / product
      t.string :canonical_name, null: false
      t.string :slug, null: false
      t.text :description
      t.jsonb :external_ids, null: false, default: {}
      t.string :status, null: false, default: "active"   # active / merged / retired
      t.timestamps
    end
    add_index :entities, [ :site_id, :slug ], unique: true
    add_index :entities, [ :site_id, :entity_type, :canonical_name ], unique: true

    create_table :entity_aliases do |t|
      t.references :entity, null: false, foreign_key: true
      t.string :alias, null: false
      t.string :language
      t.string :source
      t.float :confidence
      t.datetime :created_at, null: false
    end
    add_index :entity_aliases, [ :entity_id, :alias ], unique: true

    create_table :entity_candidates do |t|
      t.references :site, null: false, foreign_key: true
      t.string :candidate_name, null: false
      t.string :entity_type, null: false
      t.references :source_item, foreign_key: true
      t.references :proposed_entity, foreign_key: { to_table: :entities }
      t.float :confidence, null: false, default: 0
      t.string :status, null: false, default: "pending"   # pending / accepted / rejected
      t.datetime :created_at, null: false
    end

    create_table :facts do |t|
      t.references :site, null: false, foreign_key: true
      t.references :entity, null: false, foreign_key: true
      t.string :attribute_key, null: false             # `attribute` collides with ActiveRecord
      t.jsonb :value_json, null: false
      t.string :unit
      t.float :confidence, null: false, default: 0
      t.datetime :valid_from
      t.datetime :valid_until
      t.datetime :last_verified_at
      t.string :risk_level, null: false, default: "medium"    # low / medium / high
      t.string :status, null: false, default: "candidate"     # candidate / accepted / stale / retired
      t.timestamps
    end
    add_index :facts, [ :entity_id, :attribute_key ]
    add_index :facts, :last_verified_at
    add_index :facts, [ :site_id, :status ]

    create_table :claims do |t|
      t.references :site, null: false, foreign_key: true
      t.references :entity, foreign_key: true
      t.text :statement, null: false
      t.string :claim_kind, null: false             # verifiable / experiential / general
      t.float :confidence, null: false, default: 0
      t.string :status, null: false, default: "candidate"
      t.timestamps
    end

    create_table :questions do |t|
      t.references :site, null: false, foreign_key: true
      t.references :entity, foreign_key: true
      t.text :text, null: false
      t.string :language
      t.string :audience_segment
      t.integer :frequency, null: false, default: 1
      t.datetime :first_seen_at, null: false
      t.datetime :last_seen_at, null: false
      t.datetime :created_at, null: false
    end

    create_table :problems do |t|
      t.references :site, null: false, foreign_key: true
      t.references :entity, foreign_key: true
      t.text :text, null: false
      t.string :severity
      t.string :audience_segment
      t.float :confidence, null: false, default: 0
      t.datetime :created_at, null: false
    end

    create_table :experiences do |t|
      t.references :site, null: false, foreign_key: true
      t.references :entity, foreign_key: true
      t.string :person_id                           # who experienced it (an identifier string, not a users FK)
      t.string :location
      t.datetime :experienced_at
      t.text :summary, null: false
      t.text :body                                  # the person's own words; the source of Experiential Claims
      t.jsonb :metadata, null: false, default: {}
      t.datetime :created_at, null: false
    end

    create_table :evidence_links do |t|
      t.references :evidence, null: false, foreign_key: true
      t.string :knowledge_type, null: false
      t.bigint :knowledge_id, null: false
      t.string :relation_type, null: false, default: "supports"   # supports / contradicts / mentions
      t.datetime :created_at, null: false
    end
    add_index :evidence_links, [ :knowledge_type, :knowledge_id ]
    add_index :evidence_links, [ :evidence_id, :knowledge_type, :knowledge_id ], unique: true, name: "index_evidence_links_unique"

    create_table :knowledge_versions do |t|
      t.string :knowledge_type, null: false
      t.bigint :knowledge_id, null: false
      t.integer :version, null: false
      t.jsonb :snapshot, null: false
      t.string :change_reason
      t.string :changed_by_type
      t.bigint :changed_by_id
      t.datetime :created_at, null: false
    end
    add_index :knowledge_versions, [ :knowledge_type, :knowledge_id, :version ], unique: true
  end
end
