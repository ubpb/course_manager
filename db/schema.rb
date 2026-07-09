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

ActiveRecord::Schema[8.1].define(version: 2026_07_09_120001) do
  create_table "categories", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.string "color_code", null: false
    t.datetime "created_at", null: false
    t.integer "position"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["position"], name: "index_categories_on_position"
    t.index ["title"], name: "index_categories_on_title", unique: true
  end

  create_table "certificates", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "digest", null: false
    t.string "initials", null: false
    t.bigint "registration_id"
    t.datetime "updated_at", null: false
    t.index ["registration_id"], name: "index_certificates_on_registration_id"
  end

  create_table "certifications", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.text "learning_results"
    t.string "signature"
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_certifications_on_event_id", unique: true
  end

  create_table "events", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "date_and_time", null: false
    t.integer "duration"
    t.string "email_from"
    t.string "location"
    t.integer "max_no_of_participants", default: 0, null: false
    t.bigint "offer_id", null: false
    t.boolean "online", default: false, null: false
    t.boolean "published", default: false, null: false
    t.boolean "registration_required", default: false, null: false
    t.integer "registrations_count", default: 0, null: false
    t.text "reminder_message"
    t.datetime "updated_at", null: false
    t.index ["offer_id"], name: "index_events_on_offer_id"
    t.index ["published"], name: "index_events_on_published"
  end

  create_table "offers", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.boolean "archived", default: false, null: false
    t.string "contact_email"
    t.string "contact_name"
    t.string "contact_phone"
    t.datetime "created_at", null: false
    t.text "description"
    t.boolean "events_on_request", default: false, null: false
    t.text "learning_targets"
    t.bigint "old_id"
    t.boolean "published", default: false, null: false
    t.string "title", null: false
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.index ["archived"], name: "index_offers_on_archived"
    t.index ["old_id"], name: "index_offers_on_old_id"
    t.index ["published"], name: "index_offers_on_published"
    t.index ["type"], name: "index_offers_on_type"
  end

  create_table "offers_target_groups", id: false, charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "offer_id", null: false
    t.bigint "target_group_id", null: false
    t.index ["offer_id"], name: "fk_rails_80434b760c"
    t.index ["target_group_id"], name: "fk_rails_8878a00c07"
  end

  create_table "offers_topics", id: false, charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "offer_id", null: false
    t.bigint "topic_id", null: false
    t.index ["offer_id"], name: "fk_rails_9eb23d3825"
    t.index ["topic_id"], name: "fk_rails_1191bd8f67"
  end

  create_table "registrations", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.timestamp "certificate_sent_at"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.bigint "event_id", null: false
    t.string "field_of_interest"
    t.string "first_name", null: false
    t.boolean "gdrp_consent", default: false, null: false
    t.text "internal_notes"
    t.string "last_name", null: false
    t.timestamp "reminder_message_sent_at"
    t.datetime "updated_at", null: false
    t.text "user_notes"
    t.index ["event_id"], name: "index_registrations_on_event_id"
  end

  create_table "reports", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.integer "audiences", default: 0
    t.integer "categories", default: 0
    t.datetime "created_at", null: false
    t.integer "duration", null: false
    t.bigint "event_id", null: false
    t.integer "focus", default: 0
    t.integer "forms", default: 0
    t.string "lecturer", null: false
    t.integer "lecturer_gd", default: 0
    t.integer "lecturer_hd", default: 0
    t.integer "lecturer_md", default: 0
    t.integer "levels", default: 0
    t.integer "number_of_participants", null: false
    t.integer "organization_types", default: 0
    t.integer "presence_types", default: 0
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_reports_on_event_id", unique: true
  end

  create_table "target_groups", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "position"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["position"], name: "index_target_groups_on_position"
    t.index ["title"], name: "index_target_groups_on_title", unique: true
  end

  create_table "topics", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "position"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["position"], name: "index_topics_on_position"
    t.index ["title"], name: "index_topics_on_title", unique: true
  end

  add_foreign_key "certificates", "registrations"
  add_foreign_key "certifications", "events"
  add_foreign_key "events", "offers"
  add_foreign_key "offers_target_groups", "offers"
  add_foreign_key "offers_target_groups", "target_groups"
  add_foreign_key "offers_topics", "offers"
  add_foreign_key "offers_topics", "topics"
  add_foreign_key "registrations", "events"
  add_foreign_key "reports", "events"
end
