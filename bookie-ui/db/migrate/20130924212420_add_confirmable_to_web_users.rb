class AddConfirmableToWebUsers < ActiveRecord::Migration
  def up
    add_column :web_users, :confirmation_token, :string
    add_column :web_users, :confirmed_at, :datetime
    add_column :web_users, :confirmation_sent_at, :datetime
    add_column :web_users, :unconfirmed_email, :string
    add_index :web_users, :confirmation_token, :unique => true
    # User.reset_column_information # Need for some types of updates, but not for update_all.
    # To avoid a short time window between running the migration and updating all existing
    # users as confirmed, do the following
    WebUser.update_all(:confirmed_at => Time.now)
    # All existing user accounts should be able to log in after this.
  end

  def down
    remove_column :web_users, :confirmation_token, :confirmed_at
    remove_column :web_users, :confirmation_sent_at, :unconfirmed_email
  end
end
