import { Controller } from "@hotwired/stimulus"
import {
  matchesAnyQuery,
  normalizeToken,
  parseCsvTokens,
  refreshCsvAutocompleteOptions
} from "controllers/utils/csv_filter_utils"

export default class extends Controller {
  static targets = [
    "attributeInput",
    "attributeDatalist",
    "winnerInput",
    "winnerDatalist",
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
    this.attributeAutocompleteOptions = this.hasAttributeDatalistTarget
      ? this.datalistValues(this.attributeDatalistTarget)
      : []
    this.winnerAutocompleteOptions = this.hasWinnerDatalistTarget
      ? this.datalistValues(this.winnerDatalistTarget)
      : []

    this.refreshAttributeAutocomplete()
    this.refreshWinnerAutocomplete()
    this.renderCounter(this.rows.length)
    this.applyFilters()
  }

  applyFilters() {
    const attributeQueries = parseCsvTokens(this.attributeInputTarget.value)
    const attributeQuerySet = new Set(attributeQueries)
    const attributeQueryList = Array.from(attributeQuerySet)

    const winnerQueries = parseCsvTokens(this.winnerInputTarget.value)
    const winnerQuerySet = new Set(winnerQueries)
    const winnerQueryList = Array.from(winnerQuerySet)

    let visibleTotal = 0

    this.rows.forEach((row) => {
      const attributeValue = this.normalize(row.dataset.compareAttributeValue)
      const winnerValue = this.normalize(row.dataset.compareWinnerValue)

      const attributeMatches = matchesAnyQuery([ attributeValue ], attributeQuerySet, attributeQueryList)
      const winnerMatches = matchesAnyQuery([ winnerValue ], winnerQuerySet, winnerQueryList)

      row.hidden = !(attributeMatches && winnerMatches)

      if (!row.hidden) {
        visibleTotal += 1
      }
    })

    this.refreshAttributeAutocomplete()
    this.refreshWinnerAutocomplete()
    this.renderCounter(visibleTotal)
    this.renderResultsSummary(visibleTotal)
  }

  clearFilters() {
    this.attributeInputTarget.value = ""
    this.winnerInputTarget.value = ""
    this.applyFilters()
  }

  refreshAttributeAutocomplete() {
    if (!this.hasAttributeDatalistTarget) {
      return
    }

    refreshCsvAutocompleteOptions({
      inputElement: this.attributeInputTarget,
      datalistElement: this.attributeDatalistTarget,
      sourceOptions: this.attributeAutocompleteOptions
    })
  }

  refreshWinnerAutocomplete() {
    if (!this.hasWinnerDatalistTarget) {
      return
    }

    refreshCsvAutocompleteOptions({
      inputElement: this.winnerInputTarget,
      datalistElement: this.winnerDatalistTarget,
      sourceOptions: this.winnerAutocompleteOptions
    })
  }

  datalistValues(datalistElement) {
    return Array.from(datalistElement.options)
      .map((option) => option.value)
      .filter(Boolean)
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
    return normalizeToken(value)
  }
}
