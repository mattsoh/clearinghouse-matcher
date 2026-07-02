class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :hcb_user_id, null: false
      t.string :email
      t.string :name
      t.text :access_token
      t.text :refresh_token
      t.datetime :token_expires_at

      t.timestamps
    end
    add_index :users, :hcb_user_id, unique: true
  end
end
