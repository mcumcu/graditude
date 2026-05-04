import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    publishableKey: String
  }

  connect() {
    if (!this.hasPublishableKeyValue) {
      throw new Error("Stripe publishable key is missing. Add data-stripe-publishable-key-value to the controller element.")
    }

    if (typeof Stripe === "undefined") {
      throw new Error("Stripe.js is not loaded. Add <script src=\"https://js.stripe.com/v3/\"></script> to your application layout.")
    }

    this.stripe = Stripe(this.publishableKeyValue)
    this.element.__stripe = this.stripe

    // Initialize Elements or Checkout here.
    // Example: const elements = this.stripe.elements();
  }
}
