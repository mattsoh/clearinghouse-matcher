class CreateMatches < ActiveRecord::Migration[8.0]
  def change
    create_table :matches do |t|
      t.string :hcb_organization_id, null: false
      t.text :note
      t.integer :discrepancy_cents, null: false, default: 0
      t.bigint :created_by_user_id, null: false
      t.datetime :undone_at
      t.bigint :undone_by_user_id
      t.integer :legacy_id

      t.timestamps
    end
    add_index :matches, :hcb_organization_id
    add_index :matches, [:hcb_organization_id, :undone_at]
    add_index :matches, :legacy_id, unique: true
    add_foreign_key :matches, :users, column: :created_by_user_id
    add_foreign_key :matches, :users, column: :undone_by_user_id
  end
end
