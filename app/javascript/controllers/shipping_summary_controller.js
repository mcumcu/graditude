import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["shippingAmount", "subtotalAmount"]
  static values = {
    itemsTotalCents: Number,
    currency: String
  }

  connect() {
    this.update()
  }

  update() {
    const selected = this.element.querySelectorAll("input[name^='shipping_rate_ids[']:checked")
    let shippingTotalCents = 0

    selected.forEach((input) => {
      const cents = parseInt(input.dataset.shippingTotalCents || "0", 10)
      if (!Number.isNaN(cents)) {
        shippingTotalCents += cents
      }
    })

    if (this.hasShippingAmountTarget) {
      this.shippingAmountTarget.textContent = this.formatCurrency(shippingTotalCents)
    }

    if (this.hasSubtotalAmountTarget) {
      const itemsTotalCents = this.hasItemsTotalCentsValue ? this.itemsTotalCentsValue : 0
      const subtotalCents = itemsTotalCents + shippingTotalCents
      this.subtotalAmountTarget.textContent = this.formatCurrency(subtotalCents)
    }
  }

  formatCurrency(cents) {
    const currency = this.hasCurrencyValue && this.currencyValue ? this.currencyValue : "USD"
    const amount = (cents || 0) / 100.0

    try {
      return new Intl.NumberFormat("en-US", { style: "currency", currency: currency }).format(amount)
    } catch (error) {
      return `$${amount.toFixed(2)}`
    }
  }
}
