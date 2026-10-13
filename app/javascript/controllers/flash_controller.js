import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    timeout: { type: Number, default: 4000 }
  }

  connect() {
    this.timer = setTimeout(() => {
      this.dismiss()
    }, this.timeoutValue)
  }

  disconnect() {
    if (this.timer) {
      clearTimeout(this.timer)
    }
  }

  dismiss() {
    this.element.classList.remove("show")
    this.element.style.transition = "opacity 0.5s ease, transform 0.5s ease"
    this.element.style.opacity = "0"
    this.element.style.transform = "translateY(-8px)"

    setTimeout(() => {
      if (this.element && this.element.parentNode) {
        this.element.remove()
      }
    }, 500)
  }
}
