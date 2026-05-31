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

ActiveRecord::Schema[8.1].define(version: 2026_05_31_170001) do
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
    t.string "slug", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "version", default: 1, null: false
    t.integer "year"
    t.index ["slug"], name: "index_competition_templates_on_slug", unique: true
  end

  create_table "draws", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
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
    t.string "name", null: false
    t.string "public_id", limit: 26, null: false
    t.string "registered_ip"
    t.bigint "sweepstake_id", null: false
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.index ["claim_token"], name: "index_participants_on_claim_token", unique: true
    t.index ["public_id"], name: "index_participants_on_public_id", unique: true
    t.index ["sweepstake_id"], name: "index_participants_on_sweepstake_id"
  end

  create_table "sweepstakes", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.integer "allocation_rule", default: 0, null: false
    t.bigint "competition_template_id"
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "draw_at"
    t.integer "max_participants"
    t.string "name", null: false
    t.boolean "participants_public", default: true, null: false
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
  add_foreign_key "sweepstakes", "competition_templates"
  add_foreign_key "sweepstakes", "users"
  add_foreign_key "template_entries", "competition_templates"
end
