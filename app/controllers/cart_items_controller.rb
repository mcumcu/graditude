class CartItemsController < ApplicationController
  def create
    cart = current_cart
    product = Product.find(params.require(:product_id))
    certificate = Current.user.certificates.find(params.require(:certificate_id))
    price_map = StripePriceMap.find_by!(product: product)

    cart_item = cart.certificate_products.create!(
      product: product,
      certificate: certificate,
      stripe_price_map: price_map,
      quantity: params.fetch(:quantity, 1)
    )

    respond_to do |format|
      format.html { redirect_to cart_path, notice: "Added to cart." }
      format.json { render json: cart_item.as_json(only: %i[id quantity status], methods: %i[total_cents]), status: :created }
    end
  end

  def destroy
    cart_item = current_cart.certificate_products.find(params[:id])
    cart_item.destroy!
    head :no_content
  end

  private

  def current_cart
    Cart.open_for(Current.user)
  end
end
