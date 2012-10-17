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
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 0) do

  create_table "groups", :force => true do |t|
    t.string "name", :limit => 50, :null => false
  end

  add_index "groups", ["name"], :name => "name", :unique => true

  create_table "jobs", :force => true do |t|
    t.integer  "user_id",    :null => false
    t.integer  "wall_time",  :null => false
    t.integer  "cpu_time",   :null => false
    t.datetime "start_time", :null => false
    t.integer  "memory",     :null => false
    t.integer  "server_id",  :null => false
  end

  create_table "servers", :force => true do |t|
    t.string "name", :limit => 100, :null => false
  end

  add_index "servers", ["name"], :name => "name", :unique => true

  create_table "users", :force => true do |t|
    t.string  "name",     :limit => 50, :null => false
    t.integer "group_id",               :null => false
  end

  add_index "users", ["name", "group_id"], :name => "name", :unique => true

end
