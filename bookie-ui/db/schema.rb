# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20130925001233) do

  create_table "job_summaries", force: :cascade do |t|
    t.integer "user_id",      null: false
    t.integer "system_id",    null: false
    t.date    "date",         null: false
    t.string  "command_name", null: false
    t.integer "cpu_time",     null: false
    t.integer "memory_time",  null: false
  end

  add_index "job_summaries", ["command_name"], name: "index_job_summaries_on_command_name"
  add_index "job_summaries", ["date", "user_id", "system_id", "command_name"], name: "identity", unique: true
  add_index "job_summaries", ["date"], name: "index_job_summaries_on_date"

  create_table "jobs", force: :cascade do |t|
    t.integer  "user_id",                 null: false
    t.integer  "system_id",               null: false
    t.string   "command_name", limit: 24, null: false
    t.datetime "start_time",              null: false
    t.datetime "end_time",                null: false
    t.integer  "wall_time",               null: false
    t.integer  "cpu_time",                null: false
    t.integer  "memory",                  null: false
    t.integer  "exit_code",               null: false
  end

  add_index "jobs", ["command_name"], name: "index_jobs_on_command_name"
  add_index "jobs", ["exit_code"], name: "index_jobs_on_exit_code"
  add_index "jobs", ["start_time", "end_time"], name: "index_jobs_on_start_time_and_end_time"
  add_index "jobs", ["system_id"], name: "index_jobs_on_system_id"
  add_index "jobs", ["user_id"], name: "index_jobs_on_user_id"

  create_table "system_capacities", force: :cascade do |t|
    t.integer  "system_id",            null: false
    t.datetime "start_time",           null: false
    t.datetime "end_time"
    t.integer  "cores",                null: false
    t.integer  "memory",     limit: 8, null: false
  end

  add_index "system_capacities", ["start_time", "end_time"], name: "index_system_capacities_on_start_time_and_end_time"
  add_index "system_capacities", ["system_id"], name: "index_system_capacities_on_system_id"

  create_table "system_types", force: :cascade do |t|
    t.string  "name",                       null: false
    t.integer "memory_stat_type", limit: 1, null: false
  end

  add_index "system_types", ["name"], name: "index_system_types_on_name", unique: true

  create_table "systems", force: :cascade do |t|
    t.string  "name",           null: false
    t.integer "system_type_id", null: false
  end

  add_index "systems", ["name"], name: "index_systems_on_name", unique: true
  add_index "systems", ["system_type_id"], name: "index_systems_on_system_type_id"

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
  end

  add_index "users", ["name"], name: "index_users_on_name", unique: true

  create_table "web_users", force: :cascade do |t|
    t.string   "email",          null: false
    t.string   "password_hash"
    t.string   "password_salt"
    t.string   "reset_key_hash"
    t.datetime "reset_sent_at"
  end

  add_index "web_users", ["email"], name: "index_web_users_on_email", unique: true

end
