class ProductsController < ApplicationController
  allow_unauthenticated_access only: :show
  helper CertificatesHelper

  def show
    @template = params[:template].presence || ENV.fetch("DEFAULT_CERTIFICATE_TEMPLATE", "boulder")
    @products = Product.for_certificate_template(@template)
    @preferred_format = params[:preferred_format].presence
  end
end
