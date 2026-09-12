class CreateInterviews < ActiveRecord::Migration[8.1]
  def change
    create_table :interviews do |t|
      t.references :site, null: false, foreign_key: true
      t.string :status, null: false, default: "in_progress"   # in_progress / ready / completed / abandoned
      t.string :archetype_hypothesis
      t.float :archetype_confidence
      t.jsonb :slot_state, null: false, default: {}           # { slot_key => { value:, source_item_id:, confidence: } }
      t.integer :question_count, null: false, default: 0
      t.datetime :started_at, null: false
      t.datetime :completed_at
      t.timestamps
    end

    create_table :interview_turns do |t|
      t.references :interview, null: false, foreign_key: true
      t.integer :position, null: false
      t.text :question_text, null: false
      t.jsonb :examples, null: false, default: []
      t.string :question_kind, null: false                     # role / topic / purpose / open / clarify / slot:<key>
      t.text :answer_text
      t.datetime :answered_at
      t.references :source_item, foreign_key: true
      t.timestamps
    end
    add_index :interview_turns, [ :interview_id, :position ], unique: true
  end
end
