class AddDataToCertificate < ActiveRecord::Migration[8.0]
  def change
    add_column :certificates, :data, :jsonb, default: {}, null: false
  end
end
