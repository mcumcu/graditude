class CartItemsController < ApplicationController
  def create
    cart = current_cart
    product = Product.find(params.require(:product_id))
    certificate = Current.user.certificates.find(params.require(:certificate_id))

    stripe_price_id = begin
      product.stripe_price_id
    rescue Stripe::StripeError => error
      respond_to do |format|
        format.html { redirect_to cart_path, alert: "This product is not currently available for purchase." }
        format.json { render json: { error: error.message }, status: :unprocessable_entity }
      end
      return
    end

    unless stripe_price_id.present?
      respond_to do |format|
        format.html { redirect_to cart_path, alert: "This product is not currently available for purchase." }
        format.json { render json: { error: "No active price is available for this product." }, status: :unprocessable_entity }
      end
      return
    end

    cart_item = cart.certificate_products.create(
      product: product,
      certificate: certificate,
      stripe_price_id: stripe_price_id,
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
