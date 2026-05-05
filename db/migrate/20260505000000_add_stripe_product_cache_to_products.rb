class AddStripeProductCacheToProducts < ActiveRecord::Migration[8.0]
  def up
    add_column :products, :stripe_product_cache, :jsonb, null: false, default: {}
    add_index :products, :stripe_product_cache, using: :gin

    execute <<~SQL
      UPDATE products
      SET stripe_product_cache = details->'stripe'->'product'
      WHERE details->'stripe'->'product' IS NOT NULL
    SQL
  end

  def down
    remove_index :products, :stripe_product_cache
    remove_column :products, :stripe_product_cache
  end
end
