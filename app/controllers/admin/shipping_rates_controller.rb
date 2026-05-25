module Admin
  class ShippingRatesController < BaseController
    before_action :set_shipping_rate, only: %i[edit update destroy]

    def index
      @shipping_rates = ShippingRate.order(created_at: :desc)
    end

    def new
      @form = Admin::ShippingRateForm.new(
        active: true,
        default_rate: false,
        currency: "usd",
        product_format: "framed",
        billing_basis: "per_item"
      )
    end

    def create
      @form = Admin::ShippingRateForm.new(form_params)

      if @form.save
        ::Shipping::Broadcasts.rate_created(@form.shipping_rate)
        redirect_to admin_shipping_rates_path, notice: "Shipping rate created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @form = Admin::ShippingRateForm.from_shipping_rate(@shipping_rate)
    end

    def update
      @form = Admin::ShippingRateForm.new(form_params.merge(shipping_rate: @shipping_rate))

      if @form.save
        ::Shipping::Broadcasts.rate_updated(@form.shipping_rate)
        redirect_to edit_admin_shipping_rate_path(@shipping_rate), notice: "Shipping rate updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @form = Admin::ShippingRateForm.new(shipping_rate: @shipping_rate)

      if @form.archive
        ::Shipping::Broadcasts.rate_updated(@shipping_rate)
        redirect_to admin_shipping_rates_path, notice: "Shipping rate archived."
      else
        redirect_to edit_admin_shipping_rate_path(@shipping_rate), alert: @form.errors.full_messages.to_sentence
      end
    end

    private

    def set_shipping_rate
      @shipping_rate = ShippingRate.find(params[:id])
    end

    def form_params
      params.require(:shipping_rate).permit(
        :display_name,
        :product_format,
        :billing_basis,
        :amount,
        :currency,
        :delivery_min_days,
        :delivery_max_days,
        :active,
        :default_rate
      )
    end
  end
end
