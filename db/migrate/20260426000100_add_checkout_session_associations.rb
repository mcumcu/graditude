class AddCheckoutSessionAssociations < ActiveRecord::Migration[8.0]
  def change
    add_column :checkout_sessions, :stripe_session_id, :string
    add_column :checkout_sessions, :status, :string, default: "open", null: false
    add_index :checkout_sessions, :stripe_session_id, unique: true

    create_table :checkout_session_certificates, id: :uuid do |t|
      t.uuid :checkout_session_id, null: false
      t.uuid :certificate_id, null: false

      t.timestamps
    end

    add_index :checkout_session_certificates, :checkout_session_id
    add_index :checkout_session_certificates, :certificate_id
    add_foreign_key :checkout_session_certificates, :checkout_sessions
    add_foreign_key :checkout_session_certificates, :certificates
  end
end
