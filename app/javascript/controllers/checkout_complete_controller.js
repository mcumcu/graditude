import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  async initialize() {
    const queryString = window.location.search
    const urlParams = new URLSearchParams(queryString)
    const sessionId = urlParams.get("session_id")
    const response = await fetch(`checkout/${sessionId}`)
    const session = await response.json()

    if (session.status == "open") {
      window.location.replace("/certificates")
    } else if (session.status == "complete") {
      document.getElementById("success").classList.remove("hidden")
      document.getElementById("customer-email").textContent = session.customer_email
    }
  }
}