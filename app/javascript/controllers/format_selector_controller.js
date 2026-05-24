import { Controller } from "@hotwired/stimulus"

// Enables or disables a submit button based on radio selection.
export default class extends Controller {
  static targets = ["input", "submit"]
  static values = {
    requiresSelection: Boolean
  }

  connect() {
    this.update()
  }

  update() {
    if (!this.hasSubmitTarget || !this.requiresSelectionValue) {
      return
    }

    const selected = this.inputTargets.find((input) => input.checked && !input.disabled)
    const disabled = !selected

    this.submitTarget.disabled = disabled
    this.submitTarget.setAttribute("aria-disabled", disabled.toString())
    this.submitTarget.classList.toggle("opacity-50", disabled)
    this.submitTarget.classList.toggle("cursor-not-allowed", disabled)
  }
}
