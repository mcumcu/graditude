class CreateCertificateProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :certificate_products, id: :uuid do |t|
      t.uuid :cart_id, null: false
      t.uuid :certificate_id, null: false
      t.uuid :product_id, null: false
      t.uuid :stripe_price_map_id, null: false
      t.uuid :checkout_session_id
      t.string :status, null: false, default: "pending"
      t.integer :quantity, null: false, default: 1

      t.timestamps
    end

    add_index :certificate_products, :cart_id
    add_index :certificate_products, :certificate_id
    add_index :certificate_products, :product_id
    add_index :certificate_products, :stripe_price_map_id
    add_index :certificate_products, :checkout_session_id

    add_foreign_key :certificate_products, :carts
    add_foreign_key :certificate_products, :certificates
    add_foreign_key :certificate_products, :products
    add_foreign_key :certificate_products, :stripe_price_maps
    add_foreign_key :certificate_products, :checkout_sessions
  end
end
