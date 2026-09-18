import { Controller } from "@hotwired/stimulus"

// Clears comment form after successful Turbo Stream submission
export default class extends Controller {
  static targets = ["body", "submit"]

  connect() {
    this.element.addEventListener("turbo:submit-end", this.handleSubmit.bind(this))
  }

  disconnect() {
    this.element.removeEventListener("turbo:submit-end", this.handleSubmit.bind(this))
  }

  handleSubmit(event) {
    if (event.detail.success) {
      this.bodyTarget.value = ""
    }
  }
}
