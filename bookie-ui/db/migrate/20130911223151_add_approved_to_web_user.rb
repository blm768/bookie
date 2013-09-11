class AddApprovedToWebUser < ActiveRecord::Migration
  def change
    add_column :web_users, :approved, :boolean, :default => false, :null => false
    add_index :web_users, :approved
  end
end
