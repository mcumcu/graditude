import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "buttonGroup", "feedback"]

  async startCheckout(event) {
    event.preventDefault()

    this.buttonTarget.disabled = true
    this.showFeedback("Starting secure checkout...")

    try {
      const body = await this.createCheckoutSession()
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

  async createCheckoutSession() {
    const token = document.querySelector('meta[name="csrf-token"]')?.content
    if (!token) {
      throw new Error("Unable to locate CSRF token. Refresh the page and try again.")
    }

    const response = await fetch("/checkout", {
      method: "POST",
      headers: {
        Accept: "application/json",
        "X-CSRF-Token": token
      }
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
