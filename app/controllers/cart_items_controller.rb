class CartItemsController < ApplicationController
  def create
    cart = current_cart
    product_ids = Array(params[:product_ids] || params[:product_id])
      .map { |value| value.to_s.strip }
      .reject(&:blank?)
    certificate = Current.user.certificates.find(params.require(:certificate_id))

    if certificate.purchased?
      message = "This certificate has already been purchased."
      respond_to do |format|
        format.turbo_stream do
          flash.now[:alert] = message
          render turbo_stream: turbo_stream.replace("flash-messages", partial: "shared/flash_messages"), status: :unprocessable_entity
        end
        format.html { redirect_to certificate_path(certificate), alert: message }
        format.json { render json: { error: message }, status: :unprocessable_entity }
      end
      return
    end

    if product_ids.empty?
      respond_to do |format|
        format.turbo_stream do
          flash.now[:alert] = "Select at least one product to add to your cart."
          render turbo_stream: turbo_stream.replace("flash-messages", partial: "shared/flash_messages"), status: :unprocessable_entity
        end
        format.html { redirect_to cart_path, alert: "Select at least one product to add to your cart." }
        format.json { render json: { errors: [ "Select at least one product to add to your cart." ] }, status: :unprocessable_entity }
      end
      return
    end

    products = Product.where(id: product_ids).index_by(&:id)

    if products.size != product_ids.size
      respond_to do |format|
        format.turbo_stream do
          flash.now[:alert] = "One or more selected products could not be found."
          render turbo_stream: turbo_stream.replace("flash-messages", partial: "shared/flash_messages"), status: :unprocessable_entity
        end
        format.html { redirect_to cart_path, alert: "One or more selected products could not be found." }
        format.json { render json: { errors: [ "One or more selected products could not be found." ] }, status: :unprocessable_entity }
      end
      return
    end

    selected_products = product_ids.map { |id| products[id] }
    product_prices = {}

    selected_products.each do |product|
      stripe_price_id = begin
        product.stripe_price_id
      rescue Stripe::StripeError
        nil
      end

      if stripe_price_id.blank?
        respond_to do |format|
          format.turbo_stream do
            flash.now[:alert] = "This product is not currently available for purchase."
            render turbo_stream: turbo_stream.replace("flash-messages", partial: "shared/flash_messages"), status: :unprocessable_entity
          end
          format.html { redirect_to cart_path, alert: "This product is not currently available for purchase." }
          format.json { render json: { error: "No active price is available for this product." }, status: :unprocessable_entity }
        end
        return
      end

      product_prices[product] = stripe_price_id
    end

    cart_items = []

    begin
      CertificateProduct.transaction do
        product_prices.each do |product, stripe_price_id|
          cart_items << cart.certificate_products.create!(
            product: product,
            certificate: certificate,
            stripe_price_id: stripe_price_id,
            quantity: params.fetch(:quantity, 1)
          )
        end
      end
    rescue ActiveRecord::RecordInvalid => error
      respond_to do |format|
        format.turbo_stream do
          flash.now[:alert] = error.record.errors.full_messages.to_sentence
          render turbo_stream: turbo_stream.replace("flash-messages", partial: "shared/flash_messages"), status: :unprocessable_entity
        end
        format.html { redirect_to cart_path, alert: error.record.errors.full_messages.to_sentence }
        format.json { render json: { errors: error.record.errors.full_messages }, status: :unprocessable_entity }
      end
      return
    end

    if cart_items.any?
      created_items = cart_items
      respond_to do |format|
        format.turbo_stream { head :ok }
        format.html { redirect_to cart_path }
        format.json { render json: created_items.as_json(only: %i[id quantity status], methods: %i[total_cents]), status: :created }
      end
    end
  end

  def destroy
    cart_item = current_cart.certificate_products.find(params[:id])
    product = cart_item.product
    certificate = cart_item.certificate
    cart_item.destroy!
    @cart = current_cart

    if params[:source] == "cart" && @cart.certificate_products.none?
      redirect_to cart_empty_redirect_path(certificate), notice: "Removed from cart.", status: :see_other
      return
    end

    broadcast_cart_state if params[:source] == "cart"

    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = "Removed from cart."
        cart_items = @cart.certificate_products.where(certificate_id: certificate.id)
        @product = product
        @input_name = params[:input_name].presence || "product_id"
        @preferred_format = params[:preferred_format]
        @cart_product_ids = cart_items.pluck(:product_id)
        @cart_items_by_product_id = cart_items.pluck(:product_id, :id).to_h
      end
      format.html do
        if params[:source] == "cart"
          redirect_to cart_path, notice: "Removed from cart."
        else
          redirect_to cart_path, notice: "Removed from cart."
        end
      end
      format.json { head :no_content }
    end
  end

  private

  def current_cart
    Cart.open_for(Current.user)
  end

  def broadcast_cart_state
    return unless Current.user

    Turbo::StreamsChannel.broadcast_replace_to(
      [ Current.user, :cart_state ],
      target: "cart-state",
      partial: "shared/cart_state",
      locals: { cart_state_token: current_cart.state_token }
    )
  end

  def cart_empty_redirect_path(preferred_certificate = nil)
    if preferred_certificate&.persisted? && preferred_certificate.user_id == Current.user&.id
      certificate_path(preferred_certificate)
    elsif Current.user.certificates.exists?
      certificate_path(Current.user.certificates.order(updated_at: :desc).first)
    else
      product_path
    end
  end
end
