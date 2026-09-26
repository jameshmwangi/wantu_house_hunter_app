import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submit"]

  // Called on the form's 'submit' event — the browser has already committed
  // to sending the request by this point, so disabling the button is safe.
  disable(event) {
    const button = this.hasSubmitTarget ? this.submitTarget : event.submitter
    // Defer the disable so the form data (including the submit button's name/value)
    // is captured before we disable it.
    requestAnimationFrame(() => {
      button.disabled = true
      button.dataset.originalText ||= button.innerText
      button.innerText = "Processing..."
    })
  }

  // Re-enable if Turbo Stream response fails validation / errors out
  reenable() {
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = false
      this.submitTarget.innerText = this.submitTarget.dataset.originalText
    }
  }
}
