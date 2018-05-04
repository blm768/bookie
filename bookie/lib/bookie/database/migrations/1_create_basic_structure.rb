require 'active_record/migration'

require 'bookie/database'

class CreateBasicStructure < Bookie::Database::Migration
  def change
    create_table :users do |t|
      t.string :name, null: false

      t.index :name, unique: true
    end

    create_table :systems do |t|
      t.string :name, null: false
      t.references :system_type, null: false

      t.index :name, unique: true
      t.index :system_type_id
    end

    create_table :system_capacities do |t|
      t.references :system, null: false
      t.datetime :start_time, null: false
      t.datetime :end_time
      t.integer :cores, null: false
      t.integer :memory, null: false, limit: 8

      t.index :system_id
      t.index [:start_time, :end_time]
    end

    create_table :system_types do |t|
      t.string :name, null: false
      t.integer :memory_stat_type, limit: 1, null: false

      t.index :name, unique: true
    end

    create_table :jobs do |t|
      t.references :user, null: false
      t.references :system, null: false
      #TODO: re-evaluate this limit?
      t.string :command_name, limit: 24, null: false
      t.datetime :start_time, null: false
      t.datetime :end_time, null: false
      t.integer :wall_time, null: false
      t.integer :cpu_time, null: false
      t.integer :memory, null: false
      t.integer :exit_code, null: false

      t.index :user_id
      t.index :system_id
      t.index :command_name
      t.index [:start_time, :end_time]
      t.index :exit_code
    end

    create_table :job_summaries do |t|
      t.references :user, null: false
      t.references :system, null: false
      t.date :date, null: false
      t.string :command_name, null: false
      t.integer :cpu_time, null: false
      #TODO: store inexact values (i.e. MB*sec or floating-point) to prevent overflow?
      t.integer :memory_time, null: false, limit: 8

      t.index [:date, :user_id, :system_id, :command_name], unique: true, name: 'identity'
      t.index :command_name
      t.index :date
    end
  end
end
