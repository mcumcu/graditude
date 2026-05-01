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

  def stripe_test_mode?
    publishable = ENV["STRIPE_KEY_PUB"].to_s
    secret = ENV["STRIPE_KEY"].to_s
    publishable.start_with?("pk_test_") || secret.start_with?("sk_test_")
  end

  def cart_items_count
    return 0 unless Current.user

    Cart.open_for(Current.user).certificate_products.sum(:quantity)
  end
end
