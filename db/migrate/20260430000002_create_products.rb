class CreateProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :products, id: :uuid do |t|
      t.string :title, null: false
      t.text :description
      t.integer :price_cents, null: false, default: 0
      t.string :currency, null: false, default: "USD"
      t.jsonb :details, null: false, default: {}

      t.timestamps
    end

    add_index :products, :price_cents
  end
end
