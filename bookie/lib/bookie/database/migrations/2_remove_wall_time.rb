require 'active_record/migration'

require 'bookie/database'

class RemoveWallTime < ActiveRecord::Migration
  def up
    remove_column :jobs, :wall_time
  end

  def down
    change_table :jobs do |t|
      t.integer :wall_time
    end
    execute 'UPDATE jobs SET wall_time=(end_time - start_time);'
    change_column_null :jobs, :wall_time, false
  end
end
