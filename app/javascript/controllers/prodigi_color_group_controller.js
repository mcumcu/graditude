import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["hint", "colorCard", "colorButton"]
  static values = { selectedColor: String }

  connect() {
    this.selectedColorValue = ""
    this.updateView()
  }

  selectColor(event) {
    event.preventDefault()
    const color = event.currentTarget.dataset.prodigiColorGroupColorValue
    if (!color) return

    this.selectedColorValue = color
    this.clearVariantSelection()
    this.updateView()
  }

  clearSelection(event) {
    event.preventDefault()
    this.selectedColorValue = ""
    this.clearVariantSelection()
    this.updateView()
  }

  updateView() {
    const selectedColor = this.selectedColorValue

    this.hintTarget.classList.toggle("hidden", selectedColor.length > 0)

    this.colorCardTargets.forEach((card) => {
      const isActive = selectedColor.length > 0 && card.dataset.colorLabel === selectedColor
      card.classList.toggle("hidden", !isActive)
    })

    this.colorButtonTargets.forEach((button) => {
      const buttonColor = button.dataset.prodigiColorGroupColorValue
      const isSelected = buttonColor === selectedColor || (selectedColor.length === 0 && buttonColor === "")
      button.classList.toggle("border-primary/60", isSelected)
      button.classList.toggle("bg-primary/5", isSelected)
      button.classList.toggle("text-primary", isSelected)
      button.classList.toggle("border-primary/10", !isSelected)
      button.classList.toggle("bg-background-secondary", !isSelected)
      button.classList.toggle("text-content-muted", !isSelected)
    })
  }

  clearVariantSelection() {
    this.element.querySelectorAll("input[type='radio'][name='prodigi_catalog_item_id']").forEach((input) => {
      input.checked = false
    })

    this.element.dispatchEvent(new CustomEvent("clear-variant-selection", { bubbles: true }))
  }
}
