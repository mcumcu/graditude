import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "dialog"]
  static values = { url: String }

  open() {
    if (this.hasDialogTarget && !this.dialogTarget.open) {
      this.dialogTarget.showModal()
    }

    if (!this.hasUrlValue) {
      return
    }

    if (!this.hasContentTarget) {
      return
    }

    const form = this.element
    const formData = new FormData(form)
    formData.delete("_method")
    const token = document.querySelector("meta[name='csrf-token']")?.content

    this.contentTarget.innerHTML = "<div class='p-10 text-sm text-content-muted'>Loading preview…</div>"

    fetch(this.urlValue, {
      method: "POST",
      headers: {
        "X-CSRF-Token": token || "",
        Accept: "text/html"
      },
      body: formData
    })
      .then((response) => {
        if (!response.ok) {
          throw new Error(`Preview failed: ${response.status}`)
        }
        return response.text()
      })
      .then((html) => {
        this.contentTarget.innerHTML = html
      })
      .catch(() => {
        this.contentTarget.innerHTML = "<div class='p-10 text-sm text-content-muted'>Preview unavailable. Please try again.</div>"
      })
  }
}
