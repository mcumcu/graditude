require "test_helper"

class OrdersControllerTest < ActionDispatch::IntegrationTest
  test "index requires authentication" do
    get orders_url

    assert_redirected_to new_session_url
  end

  test "index shows only current user orders" do
    sign_in_as(users(:one))

    own_order = create_order_for(users(:one), stripe_session_id: "cs_order_index_1")
    create_order_for(users(:two), stripe_session_id: "cs_order_index_2")

    get orders_url

    assert_response :success
    assert_select "h1", "Order history"
    assert_match own_order.number, response.body
    assert_no_match "cs_order_index_2", response.body
  end

  test "show renders order summary for current user" do
    sign_in_as(users(:one))
    order = create_order_for(
      users(:one),
      stripe_session_id: "cs_order_show_1",
      shipping_details: {
        "stripe_shipping_details" => {
          "name" => "Floyd Miles",
          "address" => {
            "line1" => "7363 Cynthia Pass",
            "city" => "Toronto",
            "state" => "ON",
            "postal_code" => "N3Y 4H8",
            "country" => "CA"
          }
        }
      }
    )
    order.checkout_session.update!(shipping_details: {})

    get order_url(order)

    assert_response :success
    assert_select "h1", /Order ##{order.number}/
    assert_match "cs_order_show_1", response.body
    assert_match "7363 Cynthia Pass", response.body
  end

  test "show includes selected shipping options when available" do
    sign_in_as(users(:one))
    order = create_order_for(
      users(:one),
      stripe_session_id: "cs_order_show_shipping_1",
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

    get order_url(order)

    assert_response :success
    assert_match "Selected shipping option", response.body
    assert_match "USPS Ground Advantage", response.body
    assert_match "Framed • 2 items • 3-5 Business Days", response.body
    assert_match "$37.00", response.body
  end

  test "show is scoped to current user" do
    sign_in_as(users(:one))
    foreign_order = create_order_for(users(:two), stripe_session_id: "cs_order_show_2")

    get order_url(foreign_order)

    assert_response :not_found
  end

  private

  def create_order_for(user, stripe_session_id:, shipping_details: {})
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
      raw: {},
      shipping_details: shipping_details,
      stripe_session_id: stripe_session_id,
      shipping_total_cents: 500,
      shipping_currency: "usd"
    )

    checkout_session.ensure_order!
  end
end
