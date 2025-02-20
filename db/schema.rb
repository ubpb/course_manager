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

ActiveRecord::Schema[8.0].define(version: 2025_02_10_160423) do
  create_table "categories", charset: "utf8mb3", collation: "utf8mb3_uca1400_ai_ci", force: :cascade do |t|
    t.string "title", null: false
    t.string "color_code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["title"], name: "index_categories_on_title", unique: true
  end

  create_table "certificates", charset: "utf8mb3", collation: "utf8mb3_uca1400_ai_ci", force: :cascade do |t|
    t.bigint "registration_id"
    t.string "digest", null: false
    t.string "initials", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["registration_id"], name: "index_certificates_on_registration_id"
  end

  create_table "certifications", charset: "utf8mb3", collation: "utf8mb3_uca1400_ai_ci", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.text "learning_results"
    t.string "signature"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_certifications_on_event_id", unique: true
  end

  create_table "courses", charset: "utf8mb3", collation: "utf8mb3_uca1400_ai_ci", force: :cascade do |t|
    t.string "title", null: false
    t.boolean "published", default: false, null: false
    t.text "description"
    t.text "learning_targets"
    t.text "reminder_message"
    t.string "email_from"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "category_id"
    t.index ["category_id"], name: "index_courses_on_category_id"
    t.index ["published"], name: "index_courses_on_published"
  end

  create_table "courses_target_groups", id: false, charset: "utf8mb3", collation: "utf8mb3_uca1400_ai_ci", force: :cascade do |t|
    t.bigint "course_id", null: false
    t.bigint "target_group_id", null: false
    t.index ["course_id"], name: "fk_rails_26bff39dfc"
    t.index ["target_group_id"], name: "fk_rails_2fafdf950e"
  end

  create_table "courses_topics", id: false, charset: "utf8mb3", collation: "utf8mb3_uca1400_ai_ci", force: :cascade do |t|
    t.bigint "course_id", null: false
    t.bigint "topic_id", null: false
    t.index ["course_id"], name: "fk_rails_0f23d0d39a"
    t.index ["topic_id"], name: "fk_rails_da38b9ed46"
  end

  create_table "events", charset: "utf8mb3", collation: "utf8mb3_uca1400_ai_ci", force: :cascade do |t|
    t.bigint "course_id", null: false
    t.integer "registrations_count", default: 0, null: false
    t.datetime "date_and_time", null: false
    t.integer "duration"
    t.string "location"
    t.text "reminder_message"
    t.string "email_from"
    t.boolean "online", default: false, null: false
    t.boolean "published", default: false, null: false
    t.boolean "registration_required", default: false, null: false
    t.integer "max_no_of_participants", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["course_id"], name: "index_events_on_course_id"
    t.index ["published"], name: "index_events_on_published"
  end

  create_table "registrations", charset: "utf8mb3", collation: "utf8mb3_uca1400_ai_ci", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "email", null: false
    t.string "field_of_interest"
    t.text "user_notes"
    t.text "internal_notes"
    t.boolean "gdrp_consent", default: false, null: false
    t.timestamp "reminder_message_sent_at"
    t.timestamp "certificate_sent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_registrations_on_event_id"
  end

  create_table "reports", charset: "utf8mb3", collation: "utf8mb3_uca1400_ai_ci", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.integer "duration", default: 0
    t.integer "number_of_participants", default: 0
    t.string "lecturer"
    t.integer "lecturer_md", default: 0
    t.integer "lecturer_gd", default: 0
    t.integer "lecturer_hd", default: 0
    t.integer "presence_types", default: 0
    t.integer "organization_types", default: 0
    t.integer "forms", default: 0
    t.integer "levels", default: 0
    t.integer "categories", default: 0
    t.integer "audiences", default: 0
    t.integer "focus", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_reports_on_event_id", unique: true
  end

  create_table "target_groups", charset: "utf8mb3", collation: "utf8mb3_uca1400_ai_ci", force: :cascade do |t|
    t.string "title", null: false
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["position"], name: "index_target_groups_on_position"
    t.index ["title"], name: "index_target_groups_on_title", unique: true
  end

  create_table "topics", charset: "utf8mb3", collation: "utf8mb3_uca1400_ai_ci", force: :cascade do |t|
    t.string "title", null: false
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["position"], name: "index_topics_on_position"
    t.index ["title"], name: "index_topics_on_title", unique: true
  end

  add_foreign_key "certificates", "registrations"
  add_foreign_key "certifications", "events"
  add_foreign_key "courses", "categories"
  add_foreign_key "courses_target_groups", "courses"
  add_foreign_key "courses_target_groups", "target_groups"
  add_foreign_key "courses_topics", "courses"
  add_foreign_key "courses_topics", "topics"
  add_foreign_key "events", "courses"
  add_foreign_key "registrations", "events"
  add_foreign_key "reports", "events"
end
