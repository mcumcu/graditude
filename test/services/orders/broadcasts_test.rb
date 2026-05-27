require "test_helper"

class Orders::BroadcastsTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  teardown do
    Order.delete_all
    CheckoutSession.delete_all
    Cart.delete_all
  end

  test "order_updated broadcasts Turbo replace for row and detail targets" do
    order = create_order(stripe_session_id: "cs_orders_broadcast_1")

    captured = []
    with_stubbed_singleton_method(
      Turbo::StreamsChannel,
      :broadcast_replace_to,
      ->(stream, **opts) { captured << { stream: stream, opts: opts } }
    ) do
      Orders::Broadcasts.order_updated(order)
    end

    assert_equal 2, captured.size
    assert_equal [ Orders::Broadcasts::STREAM, Orders::Broadcasts::STREAM ], captured.map { |entry| entry[:stream] }
    assert_equal [ Orders::Broadcasts.row_dom_id(order), Orders::Broadcasts.detail_dom_id(order) ], captured.map { |entry| entry[:opts][:target] }
  end

  test "updating an order invokes the update broadcast callback" do
    order = create_order(stripe_session_id: "cs_orders_broadcast_2")
    captured = []

    with_stubbed_singleton_method(
      Orders::Broadcasts,
      :order_updated,
      ->(record) { captured << record }
    ) do
      order.update!(status: "processing")
    end

    assert_equal 1, captured.size
    assert_equal order.id, captured.first.id
  end

  test "updating checkout session data for an order broadcasts the order row" do
    order = create_order(stripe_session_id: "cs_orders_broadcast_3")
    captured = []

    with_stubbed_singleton_method(
      Orders::Broadcasts,
      :order_updated,
      ->(record) { captured << record }
    ) do
      order.checkout_session.update!(shipping_details: { "stripe_shipping_details" => { "name" => "Floyd Miles" } })
    end

    assert_equal 1, captured.size
    assert_equal order.id, captured.first.id
  end

  private

  def create_order(stripe_session_id:)
    user = users(:one)
    cart = Cart.create!(user: user, status: "completed")
    checkout_session = CheckoutSession.create!(
      cart: cart,
      status: :complete,
      items: [ {
        product_title: "Graditude certificate",
        quantity: 1,
        unit_amount: 7200,
        currency: "usd",
        certificate_template: "boulder"
      } ],
      raw: {},
      stripe_session_id: stripe_session_id,
      shipping_total_cents: 500,
      shipping_currency: "usd"
    )

    checkout_session.ensure_order!
  end

  def with_stubbed_singleton_method(target, method_name, replacement)
    original = target.method(method_name)
    target.define_singleton_method(method_name, &replacement)
    yield
  ensure
    target.define_singleton_method(method_name, original.to_proc) if original
  end
end
