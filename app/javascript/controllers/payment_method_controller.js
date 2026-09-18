import { Controller } from "@hotwired/stimulus"

// Toggles visual active state on payment method buttons and shows/hides form sections
export default class extends Controller {
  static targets = ["button", "mpesaForm", "cardForm"]

  select(event) {
    const clicked = event.currentTarget
    const radio = clicked.querySelector("input[type='radio']")
    if (radio) radio.checked = true

    this.buttonTargets.forEach(btn => {
      btn.classList.toggle("wantu-btn--primary", btn === clicked)
      btn.classList.toggle("wantu-btn--outline", btn !== clicked)
    })

    const method = radio ? radio.value : null
    if (this.hasMpesaFormTarget && this.hasCardFormTarget) {
      this.mpesaFormTarget.style.display = method === "mpesa" ? "" : "none"
      this.cardFormTarget.style.display = method === "card" ? "" : "none"
    }
  }
}
