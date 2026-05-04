class AddCartReferenceToCheckoutSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :checkout_sessions, :cart_id, :uuid
    add_index :checkout_sessions, :cart_id
    add_foreign_key :checkout_sessions, :carts
  end
end

# db/migrate/20260430000005_add_cart_reference_to_checkout_sessions.rb
