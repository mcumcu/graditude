class CreateCarts < ActiveRecord::Migration[8.0]
  def change
    create_table :carts, id: :uuid do |t|
      t.uuid :user_id, null: false
      t.string :status, null: false, default: "open"

      t.timestamps
    end

    add_index :carts, :user_id
    add_index :carts, [ :user_id, :status ], unique: true, where: "status = 'open'"
    add_foreign_key :carts, :users
  end
end
