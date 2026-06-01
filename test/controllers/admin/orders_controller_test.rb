require "test_helper"

class Admin::OrdersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @user = users(:one)
  end

  test "non-admin users are redirected from orders dashboard" do
    sign_in @user

    get admin_orders_url

    assert_redirected_to root_path
  end

  test "admin can view orders dashboard" do
    sign_in @admin
    order = create_order_for(users(:one), stripe_session_id: "cs_admin_index_1")

    get admin_orders_url

    assert_response :success
    assert_select "h1", "Orders"
    assert_match order.number, response.body
    assert_match "cs_admin_index_1", response.body
    assert_no_match "Mark processing", response.body
  end

  test "admin can view order detail" do
    sign_in @admin
    order = create_order_for(users(:one), stripe_session_id: "cs_admin_show_1")

    get admin_order_url(order)

    assert_response :success
    assert_select "h1", "Order ##{order.number}"
    assert_match "Fulfillment controls", response.body
    assert_match "Checkout session raw payload", response.body
    assert_match "Mark processing", response.body
  end

  test "admin order detail shows selected shipping options when available" do
    sign_in @admin
    order = create_order_for(
      users(:one),
      stripe_session_id: "cs_admin_show_shipping_1",
      shipping_details: {
        "rates" => [ {
          "display_name" => "USPS Ground Advantage",
          "product_format" => "framed",
          "billing_basis" => "per_item",
          "quantity" => 2,
          "unit_amount_cents" => 1850,
          "total_cents" => 3700,
          "currency" => "usd",
          "delivery_estimate" => {
            "minimum" => { "value" => 3, "unit" => "business_day" },
            "maximum" => { "value" => 5, "unit" => "business_day" }
          }
        } ]
      }
    )

    get admin_order_url(order)

    assert_response :success
    assert_match "Selected shipping option", response.body
    assert_match "USPS Ground Advantage", response.body
    assert_match "Framed • 2 items • 3-5 Business Days", response.body
    assert_match "$37.00", response.body
  end

  test "admin can apply a permitted fulfillment transition" do
    sign_in @admin
    order = create_order_for(users(:one), stripe_session_id: "cs_admin_transition_1")

    patch transition_admin_order_url(order), params: { status: "processing", return_to: "show" }

    assert_redirected_to admin_order_path(order)
    assert_equal "processing", order.reload.status
  end

  test "admin cannot apply an invalid fulfillment transition" do
    sign_in @admin
    order = create_order_for(users(:one), stripe_session_id: "cs_admin_transition_2")

    patch transition_admin_order_url(order), params: { status: "received", return_to: "show" }

    assert_redirected_to admin_order_path(order)
    assert_equal "order_placed", order.reload.status
    assert_equal "Cannot transition order from order_placed to received.", flash[:alert]
  end

  test "admin can apply a permitted reverse fulfillment transition when transitions allow it" do
    sign_in @admin
    order = create_order_for(users(:one), stripe_session_id: "cs_admin_transition_3", status: :shipping)

    patch transition_admin_order_url(order), params: { status: "processing", return_to: "show" }

    assert_redirected_to admin_order_path(order)
    assert_equal "processing", order.reload.status
  end

  private

  def create_order_for(user, stripe_session_id:, status: :order_placed, shipping_details: {})
    cart = Cart.create!(user: user, status: "completed")
    checkout_session = CheckoutSession.create!(
      cart: cart,
      status: :complete,
      items: [ {
        product_title: "Graditude certificate",
        product_description: "A celebratory printed certificate.",
        quantity: 1,
        unit_amount: 7200,
        currency: "usd",
        certificate_template: "boulder"
      } ],
      shipping_details: shipping_details,
      raw: {},
      stripe_session_id: stripe_session_id,
      shipping_total_cents: 500,
      shipping_currency: "usd"
    )

    order = checkout_session.ensure_order!
    order.update!(status: status) unless status.to_s == order.status
    order
  end
end
