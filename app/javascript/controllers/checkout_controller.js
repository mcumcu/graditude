import { Controller } from "@hotwired/stimulus"
import { loadStripe } from "@stripe/stripe-js"

export default class extends Controller {
  static values = {
    publishableKey: String,
    priceId: String,
    certificateIds: String
  }

  static targets = ["button", "feedback"]

  async connect() {
    this.stripe = await loadStripe(this.publishableKeyValue)
  }

  async startCheckout(event) {
    event.preventDefault()

    if (!this.priceIdValue) {
      return this.showError("Missing price id.")
    }

    this.buttonTarget.disabled = true
    this.showFeedback("✸ Starting checkout…")

    const params = new URLSearchParams({ price_id: this.priceIdValue })
    if (this.certificateIdsValue?.trim()) {
      params.append("certificate_ids", this.certificateIdsValue)
    }

    const response = await fetch("/checkout", {
      method: "POST",
      body: params
    })

    let body
    try {
      body = await response.json()
    } catch (error) {
      const text = await response.text().catch(() => "")
      this.buttonTarget.disabled = false
      return this.showError(text || error.message || "Unable to parse server response.")
    }

    if (!response.ok || body.error) {
      this.buttonTarget.disabled = false
      return this.showError(body.error || "Unable to create checkout session.")
    }

    const { error } = await this.stripe.redirectToCheckout({
      sessionId: body.sessionId
    })

    if (error) {
      this.buttonTarget.disabled = false
      this.showError(error.message)
    }
  }

  showFeedback(message) {
    if (this.hasFeedbackTarget) {
      this.feedbackTarget.textContent = message
    }
  }

  showError(message) {
    this.showFeedback(message)
  }
}
