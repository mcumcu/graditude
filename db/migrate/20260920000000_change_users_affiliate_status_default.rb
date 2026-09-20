class ChangeUsersAffiliateStatusDefault < ActiveRecord::Migration[8.1]
  def up
    change_column_default :users, :affiliate_status, from: "none", to: "inactive"
    User.where(affiliate_status: "none").update_all(affiliate_status: "inactive")
  end

  def down
    change_column_default :users, :affiliate_status, from: "inactive", to: "none"
  end
end
