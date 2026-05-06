import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal"]

  connect() {
    this.hide()
  }

  open(event) {
    event.preventDefault()
    this.show()
  }

  hide() {
    this.modalTargets.forEach((modal) => {
      modal.hidden = true
    })
  }

  show() {
    this.modalTargets.forEach((modal) => {
      modal.hidden = false
    })
  }
}
