import { Controller } from "@hotwired/stimulus"
import { loadStripe } from "@stripe/stripe-js"

export default class extends Controller {
  static values = {
    publishableKey: String
  }

  static targets = ["button", "buttonGroup", "feedback", "paymentContainer", "paymentElement", "payButton"]

  async connect() {
    if (!this.publishableKeyValue) {
      this.showError("Stripe publishable key is missing.")
      return
    }

    this.stripe = await loadStripe(this.publishableKeyValue)
    if (!this.stripe) {
      this.showError("Stripe failed to initialize.")
    }
  }

  async startCheckout(event) {
    event.preventDefault()

    if (!this.stripe) {
      this.showError("Stripe is not ready yet.")
      return
    }

    if (this.checkout) {
      this.showPaymentForm()
      return
    }

    this.buttonTarget.disabled = true
    this.showFeedback("Starting secure checkout...")

    try {
      const body = await this.createCheckoutSession()
      if (!body.clientSecret) {
        throw new Error("Missing Stripe client secret.")
      }

      await this.initializeCheckout(body.clientSecret)
      this.showPaymentForm()
      this.showFeedback("Choose a payment method and submit payment.")
    } catch (error) {
      this.showButton()
      this.showSummarySection()
      this.buttonTarget.disabled = false
      this.showError(error.message)
    }
  }

  async confirm(event) {
    event.preventDefault()

    if (!this.actions) {
      this.showError("Checkout is not ready yet.")
      return
    }

    this.payButtonTarget.disabled = true
    this.showFeedback("Confirming payment...")

    const result = await this.actions.confirm()
    if (result?.type === "error") {
      this.payButtonTarget.disabled = false
      this.showError(result.error.message || "Payment confirmation failed.")
      return
    }

    this.showFeedback("Redirecting...")
  }

  disconnect() {
    if (this.paymentElement) {
      this.paymentElement.unmount()
      this.paymentElement = null
    }
  }

  async createCheckoutSession() {
    const response = await fetch("/checkout", {
      method: "POST",
      headers: {
        Accept: "application/json"
      }
    })

    const body = await this.parseResponse(response)

    if (!response.ok || body.error) {
      throw new Error(body.error || "Unable to create checkout session.")
    }

    return body
  }

  async initializeCheckout(clientSecret) {
    this.checkout = this.stripe.initCheckoutElementsSdk({ clientSecret })

    this.checkout.on("change", (session) => {
      const canConfirm = Boolean(session?.canConfirm)
      const error = session?.error || null

      if (!this.hasPayButtonTarget) {
        return
      }

      this.payButtonTarget.disabled = !canConfirm

      if (error) {
        this.showError(error.message || "Payment element validation issue.")
        return
      }

      if (canConfirm) {
        this.showFeedback("Ready to pay.")
      } else {
        this.showFeedback("Complete the payment form to enable Pay now.")
      }
    })

    const loadActionsResult = await this.checkout.loadActions()
    if (loadActionsResult.type !== "success") {
      throw new Error(loadActionsResult.error?.message || "Unable to load Stripe checkout actions.")
    }

    this.actions = loadActionsResult.actions
    this.paymentElement = this.checkout.createPaymentElement()
    this.paymentElement.mount(this.paymentElementTarget)
  }

  showPaymentForm() {
    if (this.hasPaymentContainerTarget) {
      this.paymentContainerTarget.classList.remove("hidden")
    }

    this.hideCheckoutStartState()
  }

  hideCheckoutStartState() {
    if (this.hasButtonGroupTarget) {
      this.buttonGroupTarget.classList.add("hidden")
    }

    this.hideSummarySection()
  }

  showButton() {
    if (this.hasButtonGroupTarget) {
      this.buttonGroupTarget.classList.remove("hidden")
    }
  }

  hideSummarySection() {
    document.querySelectorAll('[data-checkout-summary-target="summary"]').forEach((element) => {
      element.classList.add("hidden")
    })
  }

  showSummarySection() {
    document.querySelectorAll('[data-checkout-summary-target="summary"]').forEach((element) => {
      element.classList.remove("hidden")
    })
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
