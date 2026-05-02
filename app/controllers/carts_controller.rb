class CartsController < ApplicationController
  def show
    @cart = current_cart
  end

  private

  def current_cart
    Cart.open_for(Current.user)
  end
end
