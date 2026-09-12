class AddInterviewExtraction < ActiveRecord::Migration[8.1]
  def change
    # Intent is never Knowledge (README §27.6): it lives here.
    create_table :goals do |t|
      t.references :site, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description, null: false          # the user's own words
      t.string :metric                          # from the archetype's default_metric; never authored by the LLM
      t.string :target_value
      t.date :target_date
      t.string :archetype
      t.string :status, null: false, default: "proposed"   # proposed / active / retired
      t.float :confidence, null: false, default: 0
      t.references :source_item, foreign_key: true
      t.timestamps
    end

    add_reference :sites, :primary_entity, foreign_key: { to_table: :entities }

    change_table :interviews do |t|
      t.jsonb :pending_question                  # next question proposed by the Extraction Agent
      t.boolean :clarification_asked, null: false, default: false
      t.integer :low_confidence_streak, null: false, default: 0
    end

    change_table :interview_turns do |t|
      t.string :extraction_status, null: false, default: "pending"   # pending / done / failed / skipped
      t.text :extraction_error
    end
  end
end
