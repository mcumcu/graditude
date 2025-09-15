class CreateCheckoutSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :checkout_sessions, id: :uuid do |t|
      t.jsonb :raw
      t.jsonb :items, array: true, default: []

      t.timestamps
    end
  end
end
