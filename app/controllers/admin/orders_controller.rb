module Admin
  class OrdersController < BaseController
    before_action :set_order, only: %i[show transition]

    def index
      @orders = Order.includes(:user, :checkout_session).recent_first
    end

    def show
    end

    def transition
      target_status = params[:status].to_s
      @order.transition_to!(target_status)
      redirect_to transition_return_path, notice: "Order #{ @order.number } updated to #{ @order.status_label }."
    rescue ArgumentError => error
      redirect_to transition_return_path, alert: error.message
    end

    private

    def set_order
      @order = Order.includes(:user, :checkout_session).find(params[:id])
    end

    def transition_return_path
      params[:return_to].to_s == "show" ? admin_order_path(@order) : admin_orders_path
    end
  end
end
