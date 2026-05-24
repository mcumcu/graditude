import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "cart-state-token"

export default class extends Controller {
  static values = { token: String }

  connect() {
    if (!this.hasTokenValue) {
      return
    }

    const storedToken = sessionStorage.getItem(STORAGE_KEY)

    if (storedToken === this.tokenValue) {
      return
    }

    sessionStorage.setItem(STORAGE_KEY, this.tokenValue)

    if (!storedToken) {
      return
    }

    if (window.Turbo && typeof window.Turbo.visit === "function") {
      window.Turbo.visit(window.location.href, { action: "replace" })
    } else {
      window.location.reload()
    }
  }
}
