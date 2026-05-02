class CartItemsController < ApplicationController
  def create
    cart = current_cart
    product = Product.find(params.require(:product_id))
    certificate = Current.user.certificates.find(params.require(:certificate_id))
    price_map = StripePriceMap.find_by(product: product, active: true)

    unless price_map
      respond_to do |format|
        format.html { redirect_to cart_path, alert: "This product is not currently available for purchase." }
        format.json { render json: { error: "No active price is available for this product." }, status: :unprocessable_entity }
      end
      return
    end
<<<<<<< HEAD

<<<<<<< HEAD

    cart_item = cart.certificate_products.create(
=======
    cart_item = cart.certificate_products.create!(
>>>>>>> origin/cart
=======
    cart_item = cart.certificate_products.create!(
>>>>>>> origin/cart
      product: product,
      certificate: certificate,
      stripe_price_map: price_map,
      quantity: params.fetch(:quantity, 1)
    )

    if cart_item.persisted?
      respond_to do |format|
        format.html { redirect_to cart_path, notice: "Added to cart." }
        format.json { render json: cart_item.as_json(only: %i[id quantity status], methods: %i[total_cents]), status: :created }
      end
    else
      respond_to do |format|
        format.html { redirect_to cart_path, alert: cart_item.errors.full_messages.to_sentence }
        format.json { render json: { errors: cart_item.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    cart_item = current_cart.certificate_products.find(params[:id])
    cart_item.destroy!

    respond_to do |format|
      format.html { redirect_to cart_path, notice: "Removed from cart." }
      format.json { head :no_content }
    end
  end

  private

  def current_cart
    Cart.open_for(Current.user)
  end
end
