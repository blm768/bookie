class CreateServers < ActiveRecord::Migration
  def create
    create_table :servers do |t|
      t.string :name, :null => false
    end
  end
end
