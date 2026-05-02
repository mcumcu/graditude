import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.timeout = window.setTimeout(() => this.hide(), 8000)
  }

  disconnect() {
    window.clearTimeout(this.timeout)
  }

  hide() {
    this.element.classList.add("opacity-0")
    window.setTimeout(() => this.element.remove(), 500)
  }
}
