class CreatePrices < ActiveRecord::Migration[8.0]
  def change
    create_table :prices, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :product_id, null: false
      t.string :stripe_price_id, null: false
      t.jsonb :stripe_price_cache, default: {}, null: false

      t.timestamps
    end

    add_index :prices, :product_id
    add_index :prices, :stripe_price_id, unique: true
    add_foreign_key :prices, :products
  end
end
