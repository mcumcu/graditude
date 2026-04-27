class CheckoutSessionCertificate < ApplicationRecord
  belongs_to :checkout_session
  belongs_to :certificate
end
