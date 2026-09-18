import { Controller } from "@hotwired/stimulus"

// Auto-submits the search form when a need_type tab (Rent/Buy/BnB/All) is clicked
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
