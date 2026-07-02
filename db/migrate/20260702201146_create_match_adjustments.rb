class CreateMatchAdjustments < ActiveRecord::Migration[8.0]
  def change
    create_table :match_adjustments do |t|
      t.bigint :match_id, null: false
      t.integer :amount_cents, null: false
      t.text :memo, null: false
      t.bigint :created_by_user_id, null: false

      t.timestamps
    end
    add_foreign_key :match_adjustments, :matches
    add_foreign_key :match_adjustments, :users, column: :created_by_user_id
    add_index :match_adjustments, :match_id
  end
end
