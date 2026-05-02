require "test_helper"

class CartTest < ActiveSupport::TestCase
  test "open_for returns an open cart for the user" do
    user = users(:one)

    cart = Cart.open_for(user)

    assert cart.open?
    assert_equal user, cart.user
  end
end
