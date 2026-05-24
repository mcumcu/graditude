module ApplicationHelper
  def form_label_classes
    "text-content-muted text-sm uppercase mb-2"
  end

  def form_input_classes(object = nil, attribute = nil)
    base = "block w-full px-3 py-2 shadow-sm rounded-md border border-black/30 dark:border-white/30 ring-1 ring-transparent focus:outline-primary dark:focus:outline-primary-dark text-xl tracking-wide bg-background-secondary dark:bg-background"

    return base unless object && attribute && object.errors[attribute].present?

    "#{base} border-error focus:border-error ring-1 ring-error/25 focus:ring-error/50 mt-1"
  end

  def field_row_classes
    "flex flex-col gap-2"
  end

  # Render the shared dark mode toggle button partial.
  # Example:
  #   <%= dark_mode_toggle %>
  #   <%= dark_mode_toggle(button_classes: "mr-4", aria_label: "Switch theme") %>
  def dark_mode_toggle(button_classes: nil, aria_label: "Toggle dark mode", **button_attrs)
    render partial: "shared/darkmode_toggle", locals: {
      button_classes: button_classes,
      aria_label: aria_label,
      button_attrs: button_attrs
    }
  end

  def modal_close_action(close_path = nil)
    if close_path
      "window.location='#{j close_path}'"
    else
      "if (history.length > 1) { history.back() } else { window.location='#{j root_path}' }"
    end
  end

  def stripe_test_mode?
    publishable = ENV["STRIPE_KEY_PUB"].to_s
    secret = ENV["STRIPE_KEY"].to_s
    publishable.start_with?("pk_test_") || secret.start_with?("sk_test_")
  end

  def cart_items_count
    return 0 unless Current.user

    cart = Current.user.open_cart
    cart ? cart.certificate_products.sum(:quantity) : 0
  end

  def cart_state_token
    return nil unless Current.user

    cart = Current.user.open_cart
    cart ? cart.state_token : "empty"
  end

  def certificates_count
    return 0 unless Current.user

    Current.user.certificates.count
  end

  def navbar_link_class(mobile: false)
    if mobile
      "-mx-3 block rounded-lg px-3 py-2 text-base/7 font-semibold text-gray-900 hover:bg-gray-50 dark:text-white dark:hover:bg-white/5 hover:cursor-pointer w-full text-left hover:decoration-underline hover:decoration-gray-900/50 dark:hover:decoration-white/50 bg-left-bottom bg-gradient-to-r from-indigo-500 to-indigo-500 bg-[length:0%_2px] bg-no-repeat hover:bg-[length:100%_2px] transition-all duration-500 ease-out"
    else
      "min-w-16 font-semibold dark:text-white pt-1.5 hover:cursor-pointer bg-left-bottom bg-gradient-to-r from-indigo-500 to-indigo-500 bg-[length:0%_2px] bg-no-repeat hover:bg-[length:100%_2px] transition-all duration-500 ease-out"
    end
  end
  def format_options_form(form_url:, form_method:, requires_selection:, products:, input_name:, preferred_format:, cart_product_ids:, cart_items_by_product_id: nil, cart_items_count: nil, certificate_id: nil, quantity: nil, &block)
    footer_html = block_given? ? capture(&block) : ""
    products = Array(products)
    cart_product_ids = Array(cart_product_ids)
    cart_items_by_product_id ||= {}

    render "shared/format_options_form",
      form_url: form_url,
      form_method: form_method,
      requires_selection: requires_selection,
      products: products,
      input_name: input_name,
      preferred_format: preferred_format,
      cart_product_ids: cart_product_ids,
      cart_items_by_product_id: cart_items_by_product_id,
      cart_items_count: cart_items_count,
      certificate_id: certificate_id,
      quantity: quantity,
      footer_html: footer_html
  end
end
