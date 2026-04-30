class CreateStripePriceMaps < ActiveRecord::Migration[8.0]
  def change
    create_table :stripe_price_maps, id: :uuid do |t|
      t.uuid :product_id, null: false
      t.string :stripe_price_id, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :stripe_price_maps, :product_id
    add_index :stripe_price_maps, :stripe_price_id, unique: true
    add_foreign_key :stripe_price_maps, :products
  end
end
