# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_10_030000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "claims", force: :cascade do |t|
    t.string "claim_kind", null: false
    t.float "confidence", default: 0.0, null: false
    t.datetime "created_at", null: false
    t.bigint "entity_id"
    t.bigint "site_id", null: false
    t.text "statement", null: false
    t.string "status", default: "candidate", null: false
    t.datetime "updated_at", null: false
    t.index ["entity_id"], name: "index_claims_on_entity_id"
    t.index ["site_id"], name: "index_claims_on_site_id"
  end

  create_table "entities", force: :cascade do |t|
    t.string "canonical_name", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "entity_type", null: false
    t.jsonb "external_ids", default: {}, null: false
    t.bigint "site_id", null: false
    t.string "slug", null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["site_id", "entity_type", "canonical_name"], name: "index_entities_on_site_id_and_entity_type_and_canonical_name", unique: true
    t.index ["site_id", "slug"], name: "index_entities_on_site_id_and_slug", unique: true
    t.index ["site_id"], name: "index_entities_on_site_id"
  end

  create_table "entity_aliases", force: :cascade do |t|
    t.string "alias", null: false
    t.float "confidence"
    t.datetime "created_at", null: false
    t.bigint "entity_id", null: false
    t.string "language"
    t.string "source"
    t.index ["entity_id", "alias"], name: "index_entity_aliases_on_entity_id_and_alias", unique: true
    t.index ["entity_id"], name: "index_entity_aliases_on_entity_id"
  end

  create_table "entity_candidates", force: :cascade do |t|
    t.string "candidate_name", null: false
    t.float "confidence", default: 0.0, null: false
    t.datetime "created_at", null: false
    t.string "entity_type", null: false
    t.bigint "proposed_entity_id"
    t.bigint "site_id", null: false
    t.bigint "source_item_id"
    t.string "status", default: "pending", null: false
    t.index ["proposed_entity_id"], name: "index_entity_candidates_on_proposed_entity_id"
    t.index ["site_id"], name: "index_entity_candidates_on_site_id"
    t.index ["source_item_id"], name: "index_entity_candidates_on_source_item_id"
  end

  create_table "evidence", force: :cascade do |t|
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.string "evidence_type", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "observed_at", null: false
    t.bigint "site_id", null: false
    t.bigint "source_item_id", null: false
    t.string "trust_level", null: false
    t.index ["site_id"], name: "index_evidence_on_site_id"
    t.index ["source_item_id"], name: "index_evidence_on_source_item_id"
  end

  create_table "evidence_links", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "evidence_id", null: false
    t.bigint "knowledge_id", null: false
    t.string "knowledge_type", null: false
    t.string "relation_type", default: "supports", null: false
    t.index ["evidence_id", "knowledge_type", "knowledge_id"], name: "index_evidence_links_unique", unique: true
    t.index ["evidence_id"], name: "index_evidence_links_on_evidence_id"
    t.index ["knowledge_type", "knowledge_id"], name: "index_evidence_links_on_knowledge_type_and_knowledge_id"
  end

  create_table "experiences", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.bigint "entity_id"
    t.datetime "experienced_at"
    t.string "location"
    t.jsonb "metadata", default: {}, null: false
    t.string "person_id"
    t.bigint "site_id", null: false
    t.text "summary", null: false
    t.index ["entity_id"], name: "index_experiences_on_entity_id"
    t.index ["site_id"], name: "index_experiences_on_site_id"
  end

  create_table "facts", force: :cascade do |t|
    t.string "attribute_key", null: false
    t.float "confidence", default: 0.0, null: false
    t.datetime "created_at", null: false
    t.bigint "entity_id", null: false
    t.datetime "last_verified_at"
    t.string "risk_level", default: "medium", null: false
    t.bigint "site_id", null: false
    t.string "status", default: "candidate", null: false
    t.string "unit"
    t.datetime "updated_at", null: false
    t.datetime "valid_from"
    t.datetime "valid_until"
    t.jsonb "value_json", null: false
    t.index ["entity_id", "attribute_key"], name: "index_facts_on_entity_id_and_attribute_key"
    t.index ["entity_id"], name: "index_facts_on_entity_id"
    t.index ["last_verified_at"], name: "index_facts_on_last_verified_at"
    t.index ["site_id", "status"], name: "index_facts_on_site_id_and_status"
    t.index ["site_id"], name: "index_facts_on_site_id"
  end

  create_table "interview_turns", force: :cascade do |t|
    t.text "answer_text"
    t.datetime "answered_at"
    t.datetime "created_at", null: false
    t.jsonb "examples", default: [], null: false
    t.bigint "interview_id", null: false
    t.integer "position", null: false
    t.string "question_kind", null: false
    t.text "question_text", null: false
    t.bigint "source_item_id"
    t.datetime "updated_at", null: false
    t.index ["interview_id", "position"], name: "index_interview_turns_on_interview_id_and_position", unique: true
    t.index ["interview_id"], name: "index_interview_turns_on_interview_id"
    t.index ["source_item_id"], name: "index_interview_turns_on_source_item_id"
  end

  create_table "interviews", force: :cascade do |t|
    t.float "archetype_confidence"
    t.string "archetype_hypothesis"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.integer "question_count", default: 0, null: false
    t.bigint "site_id", null: false
    t.jsonb "slot_state", default: {}, null: false
    t.datetime "started_at", null: false
    t.string "status", default: "in_progress", null: false
    t.datetime "updated_at", null: false
    t.index ["site_id"], name: "index_interviews_on_site_id"
  end

  create_table "knowledge_versions", force: :cascade do |t|
    t.string "change_reason"
    t.bigint "changed_by_id"
    t.string "changed_by_type"
    t.datetime "created_at", null: false
    t.bigint "knowledge_id", null: false
    t.string "knowledge_type", null: false
    t.jsonb "snapshot", null: false
    t.integer "version", null: false
    t.index ["knowledge_type", "knowledge_id", "version"], name: "idx_on_knowledge_type_knowledge_id_version_47208a0a92", unique: true
  end

  create_table "llm_usage", force: :cascade do |t|
    t.integer "cache_creation_input_tokens", default: 0, null: false
    t.integer "cache_read_input_tokens", default: 0, null: false
    t.datetime "created_at", null: false
    t.decimal "estimated_cost", precision: 12, scale: 6, default: "0.0", null: false
    t.integer "input_tokens", default: 0, null: false
    t.jsonb "metadata", default: {}, null: false
    t.string "model", null: false
    t.string "operation_type", null: false
    t.integer "output_tokens", default: 0, null: false
    t.bigint "related_id"
    t.string "related_type"
    t.bigint "site_id"
    t.boolean "succeeded", default: true, null: false
    t.index ["operation_type"], name: "index_llm_usage_on_operation_type"
    t.index ["related_type", "related_id"], name: "index_llm_usage_on_related_type_and_related_id"
    t.index ["site_id", "created_at"], name: "index_llm_usage_on_site_id_and_created_at"
    t.index ["site_id"], name: "index_llm_usage_on_site_id"
  end

  create_table "problems", force: :cascade do |t|
    t.string "audience_segment"
    t.float "confidence", default: 0.0, null: false
    t.datetime "created_at", null: false
    t.bigint "entity_id"
    t.string "severity"
    t.bigint "site_id", null: false
    t.text "text", null: false
    t.index ["entity_id"], name: "index_problems_on_entity_id"
    t.index ["site_id"], name: "index_problems_on_site_id"
  end

  create_table "questions", force: :cascade do |t|
    t.string "audience_segment"
    t.datetime "created_at", null: false
    t.bigint "entity_id"
    t.datetime "first_seen_at", null: false
    t.integer "frequency", default: 1, null: false
    t.string "language"
    t.datetime "last_seen_at", null: false
    t.bigint "site_id", null: false
    t.text "text", null: false
    t.index ["entity_id"], name: "index_questions_on_entity_id"
    t.index ["site_id"], name: "index_questions_on_site_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "site_archetypes", force: :cascade do |t|
    t.datetime "activated_at", null: false
    t.string "archetype", null: false
    t.datetime "created_at", null: false
    t.boolean "is_primary", default: false, null: false
    t.bigint "site_id", null: false
    t.datetime "updated_at", null: false
    t.index ["site_id", "archetype"], name: "index_site_archetypes_on_site_id_and_archetype", unique: true
    t.index ["site_id"], name: "index_site_archetypes_on_site_id"
    t.index ["site_id"], name: "index_site_archetypes_one_primary_per_site", unique: true, where: "is_primary"
  end

  create_table "sites", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "domain", null: false
    t.string "name", null: false
    t.string "primary_archetype"
    t.string "primary_language", default: "ja", null: false
    t.string "status", default: "setup", null: false
    t.string "timezone", default: "Asia/Tokyo", null: false
    t.datetime "updated_at", null: false
    t.string "user_role"
  end

  create_table "solid_queue_batch_executions", force: :cascade do |t|
    t.bigint "batch_id", null: false
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.index ["batch_id"], name: "index_solid_queue_batch_executions_on_batch_id"
    t.index ["job_id"], name: "index_solid_queue_batch_executions_on_job_id", unique: true
  end

  create_table "solid_queue_batches", force: :cascade do |t|
    t.string "active_job_batch_id"
    t.integer "completed_jobs", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "description"
    t.datetime "enqueued_at"
    t.datetime "failed_at"
    t.integer "failed_jobs", default: 0, null: false
    t.datetime "finished_at"
    t.text "metadata"
    t.text "on_failure"
    t.text "on_finish"
    t.text "on_success"
    t.integer "total_jobs", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_batch_id"], name: "index_solid_queue_batches_on_active_job_batch_id", unique: true
    t.index ["finished_at"], name: "index_solid_queue_batches_on_finished_at"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.bigint "batch_id"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["batch_id"], name: "index_solid_queue_jobs_on_batch_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "source_items", force: :cascade do |t|
    t.string "checksum", null: false
    t.datetime "created_at", null: false
    t.string "external_id"
    t.datetime "fetched_at", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "published_at"
    t.text "raw_content", null: false
    t.bigint "source_id", null: false
    t.string "source_url"
    t.index ["source_id", "checksum"], name: "index_source_items_on_source_id_and_checksum"
    t.index ["source_id", "external_id"], name: "index_source_items_on_source_id_and_external_id", unique: true, where: "(external_id IS NOT NULL)"
    t.index ["source_id"], name: "index_source_items_on_source_id"
  end

  create_table "sources", force: :cascade do |t|
    t.jsonb "config", default: {}, null: false
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true, null: false
    t.string "external_id"
    t.string "name", null: false
    t.bigint "site_id", null: false
    t.string "source_type", null: false
    t.string "trust_level", default: "external", null: false
    t.datetime "updated_at", null: false
    t.index ["site_id", "source_type"], name: "index_sources_on_site_id_and_source_type"
    t.index ["site_id"], name: "index_sources_on_site_id"
    t.index ["site_id"], name: "index_sources_one_interview_per_site", unique: true, where: "((source_type)::text = 'interview'::text)"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "claims", "entities"
  add_foreign_key "claims", "sites"
  add_foreign_key "entities", "sites"
  add_foreign_key "entity_aliases", "entities"
  add_foreign_key "entity_candidates", "entities", column: "proposed_entity_id"
  add_foreign_key "entity_candidates", "sites"
  add_foreign_key "entity_candidates", "source_items"
  add_foreign_key "evidence", "sites"
  add_foreign_key "evidence", "source_items"
  add_foreign_key "evidence_links", "evidence"
  add_foreign_key "experiences", "entities"
  add_foreign_key "experiences", "sites"
  add_foreign_key "facts", "entities"
  add_foreign_key "facts", "sites"
  add_foreign_key "interview_turns", "interviews"
  add_foreign_key "interview_turns", "source_items"
  add_foreign_key "interviews", "sites"
  add_foreign_key "llm_usage", "sites"
  add_foreign_key "problems", "entities"
  add_foreign_key "problems", "sites"
  add_foreign_key "questions", "entities"
  add_foreign_key "questions", "sites"
  add_foreign_key "sessions", "users"
  add_foreign_key "site_archetypes", "sites"
  add_foreign_key "solid_queue_batch_executions", "solid_queue_batches", column: "batch_id", on_delete: :cascade
  add_foreign_key "solid_queue_batch_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "source_items", "sources"
  add_foreign_key "sources", "sites"
end
