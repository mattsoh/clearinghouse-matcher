class CreateMatchTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :match_transactions do |t|
      t.bigint :match_id, null: false
      t.string :hcb_organization_id, null: false
      t.string :hcb_transaction_id, null: false
      t.integer :direction, null: false, default: 0
      t.datetime :undone_at

      t.timestamps
    end
    add_foreign_key :match_transactions, :matches
    add_index :match_transactions, :match_id
    add_index :match_transactions, [:hcb_organization_id, :hcb_transaction_id],
      unique: true, where: "undone_at IS NULL",
      name: "index_match_transactions_on_active_txn_per_org"
  end
end
