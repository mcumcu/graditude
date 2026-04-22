import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="preview"
export default class extends Controller {
  static values = {
    src: String
  }

  connect() {
    this.element.src = this.srcValue
  }
}
