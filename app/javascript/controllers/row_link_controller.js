import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  visit(event) {
    if (this.#isInteractive(event.target)) {
      return
    }

    this.#navigate()
  }

  key(event) {
    if (this.#isInteractive(event.target)) {
      return
    }

    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault()
      this.#navigate()
    }
  }

  #navigate() {
    if (!this.hasUrlValue) {
      return
    }

    window.location = this.urlValue
  }

  #isInteractive(target) {
    return target.closest("a, button, input, select, textarea, [role='button']")
  }
}
