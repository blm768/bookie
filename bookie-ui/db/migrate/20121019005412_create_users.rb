class CreateUsers < ActiveRecord::Migration
  def create
    create_table :users do |t|
      t.string :name, :null => false
      t.references :group, :null => false
    end
  end
end
