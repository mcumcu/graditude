class CreateAffiliateApplications < ActiveRecord::Migration[8.0]
  def change
    create_table :affiliate_applications, id: :uuid do |t|
      t.uuid :user_id, null: false
      t.uuid :affiliate_invitation_id
      t.uuid :reviewed_by_id
      t.string :status, null: false, default: "submitted"
      t.datetime :submitted_at
      t.datetime :reviewed_at
      t.string :display_name
      t.text :audience
      t.text :promotion_method
      t.text :notes

      t.timestamps
    end

    add_index :affiliate_applications, :user_id, unique: true
    add_index :affiliate_applications, :affiliate_invitation_id
    add_index :affiliate_applications, :reviewed_by_id

    add_foreign_key :affiliate_applications, :users
    add_foreign_key :affiliate_applications, :affiliate_invitations
    add_foreign_key :affiliate_applications, :users, column: :reviewed_by_id
  end
end
