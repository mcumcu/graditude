class ProdigiStripeMapping < ApplicationRecord
  belongs_to :prodigi_catalog_item

  validates :prodigi_catalog_item, presence: true
  validates :variant_key, presence: true
end
