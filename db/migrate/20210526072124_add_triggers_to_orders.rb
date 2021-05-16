class AddTriggersToOrders < ActiveRecord::Migration[5.2]
  def up
    drop_table :triggers
    add_column :orders, :amount_quote, :decimal, precision: 32, scale: 16, after: :market_type
    add_column :orders, :trigger_price, :decimal, precision: 32, scale: 16, after: :amount_quote
    add_column :orders, :triggered_order_id, :decimal, precision: 32, scale: 16, after: :trigger_price
    add_column :orders, :triggered_at, :datetime, after: :triggered_order_id
  end

  def down
    remove_column :orders, :amount_quote
    remove_column :orders, :trigger_price
    remove_column :orders, :triggered_order_id
    remove_column :orders, :triggered_at
  end
end
