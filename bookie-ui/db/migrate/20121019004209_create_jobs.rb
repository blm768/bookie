class CreateJobs < ActiveRecord::Migration
  def change
    create_table :jobs do |t|
      t.date date, :null => false
      t.references :user, :null => false
      t.references :server, :null => false
      t.datetime start_time, :null => false
      t.integer wall_time, :null => false
      t.integer cpu_time, :null => false
      t.integer memory, :null = false
    end
  end
end
