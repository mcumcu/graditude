class AddTemplateToCertificates < ActiveRecord::Migration[8.0]
  def change
    add_column :certificates, :template, :string
  end
end
