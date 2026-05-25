class AddShippingFieldsToCheckoutSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :checkout_sessions, :shipping_total_cents, :integer
    add_column :checkout_sessions, :shipping_currency, :string
    add_column :checkout_sessions, :shipping_details, :jsonb, default: {}, null: false

    add_index :checkout_sessions, :shipping_total_cents
  end
end
