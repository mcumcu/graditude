class AddShippingAddressToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :shipping_address, :jsonb, null: false, default: {}
  end
end
