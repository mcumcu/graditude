class ProductsController < ApplicationController
  allow_unauthenticated_access only: :show
  helper CertificatesHelper

  def show
    @template = params[:template].presence || ENV.fetch("DEFAULT_CERTIFICATE_TEMPLATE", "boulder")
    @products = Product.for_certificate_template(@template)
    @preferred_format = params[:preferred_format].presence
    @purchasable_certificates = Current.user&.certificates&.purchasable&.limit(2)&.to_a
  end
end
