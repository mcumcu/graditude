import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["option", "selectedItemId", "selectedProductId", "selectedPriceId"]

  connect() {
    this.updateSelection()
  }

  updateSelection() {
    const selectedOption = this.optionTargets.find((option) => option.checked)
    if (!selectedOption) {
      this.clearFields()
      return
    }

    this.selectedItemIdTarget.value = selectedOption.value
    this.selectedProductIdTarget.value = selectedOption.dataset.variantPickerProductIdValue || ""
    this.selectedPriceIdTarget.value = selectedOption.dataset.variantPickerPriceIdValue || ""
  }

  clearFields() {
    this.selectedItemIdTarget.value = ""
    this.selectedProductIdTarget.value = ""
    this.selectedPriceIdTarget.value = ""
  }
}
