class AddAffiliateFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :admin, :boolean, default: false, null: false
    add_column :users, :affiliate_status, :string, default: "inactive", null: false
    add_reference :users, :referred_by, type: :uuid, foreign_key: { to_table: :users }
    add_column :users, :referred_at, :datetime
    add_reference :users, :affiliate_approved_by, type: :uuid, foreign_key: { to_table: :users }
    add_column :users, :affiliate_approved_at, :datetime

    add_index :users, :affiliate_status
  end
end
