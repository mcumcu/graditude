class CreateShippingRates < ActiveRecord::Migration[8.0]
  def change
    create_table :shipping_rates, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :stripe_shipping_rate_id, null: false
      t.jsonb :stripe_shipping_rate_cache, default: {}, null: false
      t.string :product_format, null: false
      t.string :billing_basis, null: false
      t.boolean :active, null: false, default: true
      t.boolean :default_rate, null: false, default: false

      t.timestamps
    end

    add_index :shipping_rates, :stripe_shipping_rate_id, unique: true
    add_index :shipping_rates, :product_format
    add_index :shipping_rates, :billing_basis
    add_index :shipping_rates, :active
    add_index :shipping_rates, :default_rate
  end
end
