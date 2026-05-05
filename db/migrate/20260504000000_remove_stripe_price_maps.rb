class RemoveStripePriceMaps < ActiveRecord::Migration[8.0]
  def up
    add_column :certificate_products, :stripe_price_id, :string
    add_index :certificate_products, :stripe_price_id

    execute <<~SQL
      UPDATE certificate_products
      SET stripe_price_id = stripe_price_maps.stripe_price_id
      FROM stripe_price_maps
      WHERE certificate_products.stripe_price_map_id = stripe_price_maps.id
    SQL

    change_column_null :certificate_products, :stripe_price_id, false
    change_column_default :certificate_products, :stripe_price_id, nil

    remove_foreign_key :certificate_products, :stripe_price_maps, if_exists: true
    remove_reference :certificate_products, :stripe_price_map, foreign_key: false, index: true

    drop_table :stripe_price_maps
  end

  def down
    create_table :stripe_price_maps, id: :uuid do |t|
      t.uuid :product_id, null: false
      t.string :stripe_price_id, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :stripe_price_maps, :product_id
    add_index :stripe_price_maps, :stripe_price_id, unique: true

    add_reference :certificate_products, :stripe_price_map, type: :uuid, null: true, index: true

    execute <<~SQL
      WITH source_rows AS (
        SELECT id AS certificate_product_id, product_id, stripe_price_id
        FROM certificate_products
        WHERE stripe_price_id IS NOT NULL
      ), inserted_maps AS (
        INSERT INTO stripe_price_maps (id, product_id, stripe_price_id, active, created_at, updated_at)
        SELECT gen_random_uuid(), product_id, stripe_price_id, true, NOW(), NOW()
        FROM source_rows
        RETURNING id, product_id, stripe_price_id
      )
      UPDATE certificate_products
      SET stripe_price_map_id = inserted_maps.id
      FROM inserted_maps
      WHERE certificate_products.product_id = inserted_maps.product_id
        AND certificate_products.stripe_price_id = inserted_maps.stripe_price_id
    SQL

    change_column_null :certificate_products, :stripe_price_map_id, false
    add_foreign_key :certificate_products, :stripe_price_maps

    change_column_null :certificate_products, :stripe_price_id, true
    remove_index :certificate_products, :stripe_price_id
    remove_column :certificate_products, :stripe_price_id
  end
end
