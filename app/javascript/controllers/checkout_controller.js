import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "buttonGroup", "feedback"]

  async startCheckout(event) {
    event.preventDefault()

    const shippingSelection = this.collectShippingSelections()
    if (!shippingSelection.valid) {
      this.showError("Select a shipping option to continue.")
      return
    }

    this.buttonTarget.disabled = true
    this.showFeedback("Starting secure checkout...")

    try {
      const body = await this.createCheckoutSession(shippingSelection.values)
      const sessionId = body.sessionId || body.id
      if (!sessionId) {
        throw new Error("Missing Stripe checkout session ID.")
      }

      const stripeController = this.application.getControllerForElementAndIdentifier(this.element, "stripe")
      const stripeInstance = stripeController?.stripe || this.element.__stripe
      if (!stripeInstance) {
        throw new Error("Stripe controller is not initialized. Check your checkout page setup.")
      }

      const result = await stripeInstance.redirectToCheckout({ sessionId })
      if (result && result.error) {
        throw result.error
      }
    } catch (error) {
      this.buttonTarget.disabled = false
      this.showError(error.message || "Unable to start checkout.")
    }
  }

  async createCheckoutSession(shippingRateIds = {}) {
    const token = document.querySelector('meta[name="csrf-token"]')?.content
    if (!token) {
      throw new Error("Unable to locate CSRF token. Refresh the page and try again.")
    }

    const response = await fetch("/checkout", {
      method: "POST",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
        "X-CSRF-Token": token
      },
      body: JSON.stringify({ shipping_rate_ids: shippingRateIds })
    })

    const body = await this.parseResponse(response)

    if (!response.ok || body.error) {
      throw new Error(body.error || "Unable to create checkout session.")
    }

    return body
  }

  async parseResponse(response) {
    try {
      return await response.json()
    } catch (error) {
      const text = await response.text().catch(() => "")
      throw new Error(text || error.message || "Unable to parse server response.")
    }
  }

  collectShippingSelections() {
    const groups = Array.from(document.querySelectorAll("[data-shipping-format]"))
    if (groups.length === 0) {
      return { valid: true, values: {} }
    }

    const values = {}
    for (const group of groups) {
      const format = group.dataset.shippingFormat
      const input = group.querySelector(`input[name="shipping_rate_ids[${format}]"]:checked`)
      if (!input) {
        return { valid: false, values: {} }
      }
      values[format] = input.value
    }

    return { valid: true, values }
  }

  showFeedback(message, type = "success") {
    if (!this.hasFeedbackTarget) {
      return
    }

    this.feedbackTarget.textContent = message
    this.feedbackTarget.classList.toggle("text-error", type === "error")
    this.feedbackTarget.classList.toggle("text-success", type !== "error")
  }

  showError(message) {
    this.showFeedback(message, "error")
  }
}
