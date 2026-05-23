class CreateAffiliateInvitations < ActiveRecord::Migration[8.0]
  def change
    create_table :affiliate_invitations, id: :uuid do |t|
      t.string :email_address, null: false
      t.uuid :invited_by_id
      t.uuid :accepted_by_id
      t.string :status, null: false, default: "pending"
      t.datetime :expires_at
      t.datetime :accepted_at
      t.datetime :revoked_at

      t.timestamps
    end

    add_index :affiliate_invitations, :email_address
    add_index :affiliate_invitations, :invited_by_id
    add_index :affiliate_invitations, :accepted_by_id, unique: true

    add_foreign_key :affiliate_invitations, :users, column: :invited_by_id
    add_foreign_key :affiliate_invitations, :users, column: :accepted_by_id
  end
end
