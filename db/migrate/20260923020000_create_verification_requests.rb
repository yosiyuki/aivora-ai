# Asking the owner for a fact the site needs (DatabaseSchema §22-23,
# README §14). The blanks in a generated page are the question: filling an
# empty form with entities and facts is beyond a non-expert, but answering
# "what are your opening hours?" against a page that visibly lacks them is not.
class CreateVerificationRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :verification_requests do |t|
      t.references :site, null: false, foreign_key: true
      t.references :fact, null: true, foreign_key: true          # recheck: which fact went stale
      t.references :entity, null: true, foreign_key: true        # entity: which candidate is unclear
      t.references :content_claim, null: true, foreign_key: true # initial: which blank raised this

      t.string  :request_type, null: false                       # initial | recheck | entity
      t.string  :slot_key                                        # which slot is being asked about
      t.text    :question, null: false                           # shown to the owner, built in code
      t.integer :priority, null: false, default: 0               # rank, not a score; never shown
      t.string  :assigned_to                                     # column only in phase 1
      t.datetime :due_at                                         # column only in phase 1
      t.string :status, null: false, default: "open"            # open | answered | closed | superseded

      t.timestamps
      t.datetime :completed_at

      t.index [ :site_id, :status ]
      t.index [ :site_id, :slot_key, :status ]
    end

    create_table :verification_events do |t|
      t.references :verification_request, null: false, foreign_key: true
      t.references :source_item, null: true, foreign_key: true   # the answer, once stored as input

      t.string   :person_id, null: false                         # "user:1"; same shape as experiences
      t.datetime :verified_at, null: false
      t.string   :result, null: false                            # answered | skipped
      t.text     :notes                                          # the answer, verbatim
      t.string   :location
      t.float    :confidence
      t.string   :extraction_status, null: false, default: "pending"  # pending | processing | done | failed

      t.datetime :created_at, null: false

      t.index [ :extraction_status, :created_at ]
    end
  end
end
