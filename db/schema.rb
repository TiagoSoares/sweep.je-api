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

ActiveRecord::Schema[8.1].define(version: 2026_06_10_120001) do
  create_table "allocations", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "draw_id", null: false
    t.bigint "entry_id", null: false
    t.bigint "participant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["draw_id", "entry_id"], name: "index_allocations_on_draw_id_and_entry_id", unique: true
    t.index ["draw_id", "participant_id"], name: "index_allocations_on_draw_id_and_participant_id"
    t.index ["draw_id"], name: "index_allocations_on_draw_id"
    t.index ["entry_id"], name: "index_allocations_on_entry_id"
    t.index ["participant_id"], name: "index_allocations_on_participant_id"
  end

  create_table "competition_templates", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "category"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.json "prediction_fields"
    t.string "slug", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "version", default: 1, null: false
    t.integer "year"
    t.index ["slug"], name: "index_competition_templates_on_slug", unique: true
  end

  create_table "draws", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "adjusted_at"
    t.integer "algorithm_version", default: 1, null: false
    t.datetime "created_at", null: false
    t.json "entry_order", null: false
    t.json "participant_order", null: false
    t.string "public_entropy_source"
    t.string "public_entropy_value"
    t.string "public_id", limit: 26, null: false
    t.datetime "run_at", null: false
    t.bigint "run_by_id"
    t.string "seed", null: false
    t.string "seed_commitment"
    t.bigint "sweepstake_id", null: false
    t.integer "trigger", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["public_id"], name: "index_draws_on_public_id", unique: true
    t.index ["run_by_id"], name: "index_draws_on_run_by_id"
    t.index ["sweepstake_id"], name: "index_draws_on_sweepstake_id"
  end

  create_table "entries", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.json "metadata"
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.string "public_id", limit: 26, null: false
    t.bigint "sweepstake_id", null: false
    t.datetime "updated_at", null: false
    t.index ["public_id"], name: "index_entries_on_public_id", unique: true
    t.index ["sweepstake_id", "position"], name: "index_entries_on_sweepstake_id_and_position"
    t.index ["sweepstake_id"], name: "index_entries_on_sweepstake_id"
  end

  create_table "participants", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "claim_token", limit: 64, null: false
    t.datetime "created_at", null: false
    t.integer "entries_count", default: 1, null: false
    t.string "name", null: false
    t.json "predictions"
    t.string "public_id", limit: 26, null: false
    t.string "registered_ip"
    t.bigint "sweepstake_id", null: false
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.index ["claim_token"], name: "index_participants_on_claim_token", unique: true
    t.index ["public_id"], name: "index_participants_on_public_id", unique: true
    t.index ["sweepstake_id"], name: "index_participants_on_sweepstake_id"
  end

  create_table "solid_cable_messages", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.binary "channel", limit: 1024, null: false
    t.bigint "channel_hash", null: false
    t.datetime "created_at", null: false
    t.binary "payload", size: :long, null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "solid_cache_entries", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.integer "byte_size", null: false
    t.datetime "created_at", null: false
    t.binary "key", limit: 1024, null: false
    t.bigint "key_hash", null: false
    t.binary "value", size: :long, null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "solid_queue_blocked_executions", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
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

  create_table "solid_queue_claimed_executions", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
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

  create_table "solid_queue_ready_executions", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
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

  create_table "solid_queue_scheduled_executions", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "sweepstakes", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.boolean "allow_multiple_entries", default: false, null: false
    t.integer "allocation_rule", default: 0, null: false
    t.bigint "competition_template_id"
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "draw_at"
    t.integer "max_participants"
    t.string "name", null: false
    t.boolean "participants_public", default: true, null: false
    t.json "prediction_fields"
    t.json "prizes"
    t.string "public_id", limit: 26, null: false
    t.string "share_token", limit: 64, null: false
    t.integer "status", default: 1, null: false
    t.string "timezone", default: "UTC", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["competition_template_id"], name: "index_sweepstakes_on_competition_template_id"
    t.index ["public_id"], name: "index_sweepstakes_on_public_id", unique: true
    t.index ["share_token"], name: "index_sweepstakes_on_share_token", unique: true
    t.index ["user_id"], name: "index_sweepstakes_on_user_id"
  end

  create_table "template_entries", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "competition_template_id", null: false
    t.datetime "created_at", null: false
    t.json "metadata"
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["competition_template_id", "position"], name: "index_template_entries_on_competition_template_id_and_position"
    t.index ["competition_template_id"], name: "index_template_entries_on_competition_template_id"
  end

  create_table "users", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.string "public_id", limit: 26, null: false
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["public_id"], name: "index_users_on_public_id", unique: true
  end

  add_foreign_key "allocations", "draws"
  add_foreign_key "allocations", "entries"
  add_foreign_key "allocations", "participants"
  add_foreign_key "draws", "sweepstakes"
  add_foreign_key "draws", "users", column: "run_by_id"
  add_foreign_key "entries", "sweepstakes"
  add_foreign_key "participants", "sweepstakes"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "sweepstakes", "competition_templates"
  add_foreign_key "sweepstakes", "users"
  add_foreign_key "template_entries", "competition_templates"
end
