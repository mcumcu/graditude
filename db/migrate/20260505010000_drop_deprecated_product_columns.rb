class DropDeprecatedProductColumns < ActiveRecord::Migration[8.0]
  def up
    remove_index :products, :price_cents if index_exists?(:products, :price_cents)

    remove_column :products, :title, :string if column_exists?(:products, :title)
    remove_column :products, :description, :text if column_exists?(:products, :description)
    remove_column :products, :price_cents, :integer if column_exists?(:products, :price_cents)
    remove_column :products, :currency, :string if column_exists?(:products, :currency)
    remove_column :products, :details, :jsonb if column_exists?(:products, :details)
  end

  def down
    add_column :products, :title, :string, null: false, default: "" unless column_exists?(:products, :title)
    add_column :products, :description, :text unless column_exists?(:products, :description)
    add_column :products, :price_cents, :integer, null: false, default: 0 unless column_exists?(:products, :price_cents)
    add_column :products, :currency, :string, null: false, default: "USD" unless column_exists?(:products, :currency)
    add_column :products, :details, :jsonb, null: false, default: {} unless column_exists?(:products, :details)
    add_index :products, :price_cents unless index_exists?(:products, :price_cents)
  end
end
