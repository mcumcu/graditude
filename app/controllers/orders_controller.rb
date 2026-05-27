class OrdersController < ApplicationController
  def index
    @orders = Current.user.orders.includes(:checkout_session).recent_first
  end

  def show
    @order = Current.user.orders.includes(:checkout_session).find(params[:id])
  end
end
