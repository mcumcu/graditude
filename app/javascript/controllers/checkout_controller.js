import { Controller } from "@hotwired/stimulus"
import { loadStripe } from "@stripe/stripe-js"

export default class extends Controller {
  static values = {
    publishableKey: String,
    priceId: String
  }

  async initialize() {
    const stripe = await loadStripe(this.publishableKeyValue)

    const fetchClientSecret = async () => {
      const response = await fetch("/checkout", {
        method: "POST",
        body: new URLSearchParams({
          price_id: this.priceIdValue
        })
      })

      const { clientSecret } = await response.json()
      console.log(clientSecret)
      return clientSecret
    }

    const checkout = await stripe.initEmbeddedCheckout({
      fetchClientSecret,
    })

    // Mount Checkout
    checkout.mount("#checkout")
  }
}
