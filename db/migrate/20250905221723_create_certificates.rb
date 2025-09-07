class CreateCertificates < ActiveRecord::Migration[8.0]
  def change
    create_table :certificates, id: :uuid do |t|
      t.belongs_to :user, null: false, foreign_key: true, type: :uuid

      t.timestamps
    end
  end
end
