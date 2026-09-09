class CreateLlmUsage < ActiveRecord::Migration[8.1]
  def change
    create_table :llm_usage do |t|
      t.references :site, foreign_key: true, null: true
      t.string :operation_type, null: false
      t.string :model, null: false
      t.integer :input_tokens, null: false, default: 0
      t.integer :output_tokens, null: false, default: 0
      t.integer :cache_read_input_tokens, null: false, default: 0
      t.integer :cache_creation_input_tokens, null: false, default: 0
      t.decimal :estimated_cost, precision: 12, scale: 6, null: false, default: 0
      t.string :related_type
      t.bigint :related_id
      t.boolean :succeeded, null: false, default: true
      t.jsonb :metadata, null: false, default: {}
      t.datetime :created_at, null: false
    end
    add_index :llm_usage, [ :site_id, :created_at ]
    add_index :llm_usage, :operation_type
    add_index :llm_usage, [ :related_type, :related_id ]
  end
end
