import { Controller } from "@hotwired/stimulus"

// Toggles hidden content visibility (comments, reviews, etc.)
export default class extends Controller {
  static values = { target: { type: String, default: "comments-hidden" } }

  toggle(event) {
    event.preventDefault()
    const hidden = document.getElementById(this.targetValue)
    if (hidden) {
      const isVisible = hidden.style.display !== "none"
      hidden.style.display = isVisible ? "none" : "block"
      this.element.textContent = isVisible ? this.element.dataset.showText || "See all ›" : this.element.dataset.hideText || "Hide ›"
    }
  }
}
