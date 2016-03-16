class AddWebUsers < ActiveRecord::Migration
  def change
    create_table :web_users do |t|
      t.string :email, null: false
      t.string :password_hash
      t.string :password_salt
      t.string :reset_key_hash
      t.datetime :reset_sent_at

      t.index :email, unique: true
    end
  end
end
