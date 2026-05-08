import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="preview"
export default class extends Controller {
  static values = {
    src: String
  }

  connect() {
    fetch(this.srcValue)
      .then((response) => {
        if (!response.ok) {
          throw new Error(`Preview fetch failed: ${response.status}`)
        }
        return response.text()
      })
      .then((dataUrl) => {
        this.element.style.backgroundImage = dataUrl
      })
      .catch(() => {
        // Preserve the placeholder image on failure.
      })
  }
}
