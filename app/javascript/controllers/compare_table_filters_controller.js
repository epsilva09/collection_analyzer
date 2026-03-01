import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "attributeInput",
    "winnerInput",
    "visibleCount",
    "totalCount",
    "resultsSummary"
  ]

  static values = {
    resultsTemplate: String,
    totalCount: Number
  }

  connect() {
    this.rows = Array.from(this.element.querySelectorAll("[data-compare-row='true']"))
    this.renderCounter(this.rows.length)
    this.applyFilters()
  }

  applyFilters() {
    const attributeQuery = this.normalize(this.attributeInputTarget.value)
    const winnerQuery = this.normalize(this.winnerInputTarget.value)

    let visibleTotal = 0

    this.rows.forEach((row) => {
      const attributeValue = this.normalize(row.dataset.compareAttributeValue)
      const winnerValue = this.normalize(row.dataset.compareWinnerValue)

      const attributeMatches = !attributeQuery || attributeValue.includes(attributeQuery)
      const winnerMatches = !winnerQuery || winnerValue.includes(winnerQuery)

      row.hidden = !(attributeMatches && winnerMatches)

      if (!row.hidden) {
        visibleTotal += 1
      }
    })

    this.renderCounter(visibleTotal)
    this.renderResultsSummary(visibleTotal)
  }

  clearFilters() {
    this.attributeInputTarget.value = ""
    this.winnerInputTarget.value = ""
    this.applyFilters()
  }

  renderCounter(visibleTotal) {
    const total = this.hasTotalCountValue ? this.totalCountValue : this.rows.length

    if (this.hasVisibleCountTarget) {
      this.visibleCountTarget.textContent = visibleTotal.toString()
    }

    if (this.hasTotalCountTarget) {
      this.totalCountTarget.textContent = total.toString()
    }
  }

  renderResultsSummary(visibleTotal) {
    if (!this.hasResultsTemplateValue || !this.hasResultsSummaryTarget) {
      return
    }

    this.resultsSummaryTarget.textContent = this.resultsTemplateValue.replace("COUNT", visibleTotal.toString())
  }

  normalize(value) {
    return (value || "").toString().trim().toLowerCase()
  }
}
