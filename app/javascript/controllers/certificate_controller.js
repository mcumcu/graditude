import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="preview"
export default class extends Controller {
  static values = {
    src: String
  }

  static targets = [
    'img'
  ]

  connect() {
    this.load_image()
  }
  
  load_image() {
    this.imgTarget.src = this.srcValue
  }
}
