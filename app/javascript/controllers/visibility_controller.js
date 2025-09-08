import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "hideable" ]

  connect() {
    // console.log(this.hideableTargets)
    // this.showTargets()
  }

  showTargets() {
    this.hideableTargets.forEach(el => {
      el.hidden = false

      el.scrollIntoView(false)
    });
  }

  hideTargets() {
    this.hideableTargets.forEach(el => {
      el.hidden = true
    });
  }

  toggleTargets() {
    this.hideableTargets.forEach((el) => {
      el.hidden = !el.hidden

      if (!el.hidden) {
        el.scrollIntoView(false)
      }
    });
  }
}
