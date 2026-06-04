class CreateProdigiStripeMappings < ActiveRecord::Migration[8.1]
  def change
    drop_table :prodigi_stripe_mappings, if_exists: true
    create_table :prodigi_stripe_mappings, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :prodigi_catalog_item, null: false, type: :uuid, foreign_key: true
      t.string :stripe_product_id
      t.string :stripe_price_id
      t.string :stripe_shipping_rate_id
      t.string :variant_key
      t.datetime :last_synced_at
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    remove_index :prodigi_stripe_mappings, :prodigi_catalog_item_id, if_exists: true
    remove_index :prodigi_stripe_mappings, :stripe_price_id, if_exists: true
    remove_index :prodigi_stripe_mappings, :stripe_shipping_rate_id, if_exists: true
    add_index :prodigi_stripe_mappings, :prodigi_catalog_item_id, unique: true
    add_index :prodigi_stripe_mappings, :stripe_price_id, unique: true
    add_index :prodigi_stripe_mappings, :stripe_shipping_rate_id
  end
end
