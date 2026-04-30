class User < ApplicationRecord
  has_secure_password validations: false
  has_many :sessions, dependent: :destroy
  has_many :carts, dependent: :destroy
  has_one :open_cart, -> { where(status: :open) }, class_name: "Cart"
  has_many :certificates, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  validates :email_address, presence: true, uniqueness: true

  def magic_link_token
    signed_id(purpose: "magic_link", expires_in: 15.minutes)
  end

  def self.find_by_magic_link_token!(token)
    find_signed!(token, purpose: "magic_link")
  end
end
