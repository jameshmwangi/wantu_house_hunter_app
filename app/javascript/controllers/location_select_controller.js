import { Controller } from "@hotwired/stimulus"

// Cascading county → sub-county select for Kenya locations
export default class extends Controller {
  static targets = ["county", "subCounty"]
  static values = { data: Object }

  connect() {
    this.updateSubCounties()
  }

  updateSubCounties() {
    const county = this.countyTarget.value
    const subCounties = this.dataValue[county] || []
    const select = this.subCountyTarget
    const selected = select.dataset.selected || ""

    select.innerHTML = '<option value="">Select Sub-County</option>'
    subCounties.forEach(sc => {
      const option = document.createElement("option")
      option.value = sc
      option.textContent = sc
      if (sc === selected) option.selected = true
      select.appendChild(option)
    })
  }
}
