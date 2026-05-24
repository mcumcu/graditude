import { Controller } from "@hotwired/stimulus"

// Enables or disables a submit button based on radio selection.
export default class extends Controller {
  static targets = ["input", "submit", "helperText"]
  static values = {
    requiresSelection: Boolean,
    cartUrl: String
  }

  connect() {
    this.update()
    this.handleStreamRender = () => this.update()
    this.handleFrameLoad = () => this.update()
    document.addEventListener("turbo:after-stream-render", this.handleStreamRender)
    document.addEventListener("turbo:frame-load", this.handleFrameLoad)
  }

  disconnect() {
    if (this.handleStreamRender) {
      document.removeEventListener("turbo:after-stream-render", this.handleStreamRender)
    }
    if (this.handleFrameLoad) {
      document.removeEventListener("turbo:frame-load", this.handleFrameLoad)
    }
  }

  toggle(event) {
    const input = event.currentTarget

    if (input.type !== "radio") {
      return
    }

    if (input.disabled) {
      return
    }

    if (this.lastChecked === input && input.checked) {
      input.checked = false
      this.lastChecked = null
      this.update()
      return
    }

    this.lastChecked = input
    this.update()
  }

  update() {
    const inputs = this.inputTargets.filter((input) => !input.disabled)
    const selectedInputs = inputs.filter((input) => input.checked)
    const selectedCount = selectedInputs.length
    const totalCards = this.element.querySelectorAll("[data-product-card]").length
    const allInCart = totalCards > 0 && inputs.length === 0
    const selected = selectedInputs[0] || null
    this.lastChecked = selected

    if (!this.hasSubmitTarget || !this.requiresSelectionValue) {
      return
    }

    let label = "Add to cart"
    if (allInCart) {
      label = "View cart"
    } else if (selectedCount > 1) {
      label = `Add ${selectedCount} to cart`
    }

    const disabled = !allInCart && selectedCount === 0

    this.submitTarget.disabled = disabled
    this.submitTarget.setAttribute("aria-disabled", disabled.toString())
    this.submitTarget.classList.toggle("opacity-50", disabled)
    this.submitTarget.classList.toggle("cursor-not-allowed", disabled)
    this.submitTarget.value = label

    if (allInCart) {
      this.submitTarget.type = "button"
    } else {
      this.submitTarget.type = "submit"
    }

    if (this.hasHelperTextTarget) {
      const helperText = this.helperTextTargets
      const helperMessage = this.helperMessageFor({ selectedCount, allInCart })

      helperText.forEach((target) => {
        if (helperMessage) {
          target.textContent = helperMessage
        }
      })
    }
  }

  helperMessageFor({ selectedCount, allInCart }) {
    const dataSource = this.helperTextTargets[0]?.dataset || {}
    if (allInCart) {
      return dataSource.helperAll || "All formats are already in your cart."
    }

    if (selectedCount > 1) {
      return dataSource.helperMany || "We will add your selected formats to the cart."
    }

    if (selectedCount === 1) {
      return dataSource.helperOne || "We will add your selected format to the cart."
    }

    return dataSource.helperZero || "Select one or more formats to add to your cart."
  }

  submitOrNavigate(event) {
    const inputs = this.inputTargets.filter((input) => !input.disabled)
    const totalCards = this.element.querySelectorAll("[data-product-card]").length
    const allInCart = totalCards > 0 && inputs.length === 0

    if (!allInCart) {
      return
    }

    if (this.hasCartUrlValue) {
      event.preventDefault()
      window.location.assign(this.cartUrlValue)
    }
  }
}
