class AddStripeProductIdToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :stripe_product_id, :string
    add_index :products, :stripe_product_id, unique: true
  end
end
