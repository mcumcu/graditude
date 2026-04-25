import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["lightIcon", "darkIcon"]

  connect() {
    const storedTheme = localStorage.getItem('color-theme')
    const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches
    const isDark = storedTheme === 'dark' || (!storedTheme && prefersDark)

    document.documentElement.classList.toggle('dark', isDark)
    this.lightIconTarget.classList.toggle('hidden', !isDark)
    this.darkIconTarget.classList.toggle('hidden', isDark)
  }

  toggleTheme() {
    const isDark = document.documentElement.classList.toggle('dark')
    localStorage.setItem('color-theme', isDark ? 'dark' : 'light')

    this.lightIconTarget.classList.toggle('hidden', !isDark)
    this.darkIconTarget.classList.toggle('hidden', isDark)
  }
}
