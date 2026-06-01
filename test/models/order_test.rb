require "test_helper"

class OrderTest < ActiveSupport::TestCase
  test "supports ordered fulfillment transitions" do
    order = build_order

    order.process!
    order.ship!
    order.receive!

    assert_equal "received", order.reload.status
  end

  test "rejects invalid transitions" do
    order = build_order

    error = assert_raises(ArgumentError) { order.ship! }

    assert_match "Cannot transition order", error.message
  end

  test "prevents cancellation after shipping" do
    order = build_order(status: :shipping)

    assert_raises(ArgumentError) { order.cancel! }
  end

  test "previous_status_in_flow returns the previous fulfillment step" do
    order = build_order(status: :shipping)

    assert_equal "processing", order.previous_status_in_flow
  end

  test "return_transition_status is nil for the initial fulfillment step" do
    order = build_order(status: :order_placed)

    assert_nil order.return_transition_status
  end

  test "return_transition_status returns previous step when allowed by transitions" do
    order = build_order(status: :shipping)

    assert_equal "processing", order.return_transition_status
  end

  test "transition_to! uses TRANSITIONS as the canonical rule source" do
    order = build_order(status: :shipping)

    order.transition_to!("processing")

    assert_equal "processing", order.reload.status
  end

  private

  def build_order(status: :order_placed)
    user = users(:one)
    cart = Cart.create!(user: user, status: "completed")
    checkout_session = CheckoutSession.create!(
      cart: cart,
      status: :complete,
      items: [ { price_id: "price_test", quantity: 1 } ],
      raw: {},
      stripe_session_id: SecureRandom.hex(8)
    )

    Order.create!(user: user, checkout_session: checkout_session, status: status, raw: {})
  end
end
