class CreateProdigiCatalogItems < ActiveRecord::Migration[8.1]
  def change
    drop_table :prodigi_catalog_items, if_exists: true
    create_table :prodigi_catalog_items, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :row_key, null: false
      t.string :sku, null: false
      t.string :destination_country, null: false
      t.string :product_family
      t.string :shipping_method
      t.decimal :size_cm, precision: 10, scale: 4
      t.string :size_inches
      t.string :color
      t.string :frame
      t.string :paper_type
      t.integer :product_price_amount_cents
      t.string :product_currency
      t.integer :shipping_price_cents
      t.integer :plus_one_shipping_price_cents
      t.string :shipping_currency
      t.integer :minimum_shipping_days
      t.integer :maximum_shipping_days
      t.boolean :tracked_shipping
      t.string :variant_fingerprint, null: false
      t.jsonb :raw_row_data, null: false, default: {}
      t.jsonb :prodigi_product_details, null: false, default: {}
      t.timestamps
    end

    add_index :prodigi_catalog_items, :row_key, unique: true
    add_index :prodigi_catalog_items, :sku
    add_index :prodigi_catalog_items, :destination_country
    add_index :prodigi_catalog_items, :product_family
  end
end
