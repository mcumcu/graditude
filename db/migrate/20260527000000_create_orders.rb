class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.references :checkout_session, null: false, foreign_key: true, type: :uuid, index: { unique: true }
      t.string :status, null: false, default: "order_placed"
      t.jsonb :raw, null: false, default: {}
      t.timestamps
    end

    add_index :orders, :status
  end
end
