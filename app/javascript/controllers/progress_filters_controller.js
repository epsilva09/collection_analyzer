import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "statusInput",
    "statusDatalist",
    "statusMulti",
    "itemInput",
    "itemDatalist",
    "itemMulti"
  ]

  connect() {
    this.statusAutocompleteOptions = this.datalistValues(this.statusDatalistTarget)
    this.itemAutocompleteOptions = this.datalistValues(this.itemDatalistTarget)

    this.refreshStatusAutocomplete()
    this.refreshItemAutocomplete()
    this.applyFilters()
  }

  applyFilters() {
    const statusQueries = this.unique([
      ...this.parseCsvTokens(this.statusInputTarget.value),
      ...this.selectedOptions(this.statusMultiTarget)
    ])

    const itemQueries = this.unique([
      ...this.parseCsvTokens(this.itemInputTarget.value),
      ...this.selectedOptions(this.itemMultiTarget)
    ])

    this.entryElements().forEach((entry) => {
      const statusValues = this.parseEntryValues(entry.dataset.progressStatusValues)
      const itemValues = this.parseEntryValues(entry.dataset.progressMaterialValues)

      const statusMatches =
        statusQueries.length === 0 ||
        statusQueries.some((query) => statusValues.some((value) => value.includes(query)))

      const itemMatches =
        itemQueries.length === 0 ||
        itemQueries.some((query) => itemValues.some((value) => value.includes(query)))

      entry.hidden = !(statusMatches && itemMatches)
    })

    this.bucketElements().forEach((bucket) => {
      const visibleEntries = Array.from(bucket.querySelectorAll("[data-progress-entry='true']")).filter((entry) => !entry.hidden).length
      const badge = bucket.querySelector("[data-progress-count-badge='true']")

      if (badge) {
        badge.textContent = visibleEntries
      }

      bucket.hidden = visibleEntries === 0
    })

    this.refreshStatusAutocomplete()
    this.refreshItemAutocomplete()
  }

  clearFilters() {
    this.statusInputTarget.value = ""
    this.itemInputTarget.value = ""

    Array.from(this.statusMultiTarget.options).forEach((option) => {
      option.selected = false
    })

    Array.from(this.itemMultiTarget.options).forEach((option) => {
      option.selected = false
    })

    this.applyFilters()
  }

  refreshStatusAutocomplete() {
    this.refreshAutocompleteOptions(
      this.statusInputTarget,
      this.statusDatalistTarget,
      this.statusAutocompleteOptions
    )
  }

  refreshItemAutocomplete() {
    this.refreshAutocompleteOptions(
      this.itemInputTarget,
      this.itemDatalistTarget,
      this.itemAutocompleteOptions
    )
  }

  refreshAutocompleteOptions(inputElement, datalistElement, sourceOptions) {
    const rawValue = inputElement.value || ""
    const tokens = rawValue.split(",").map((token) => token.trim())
    const currentToken = this.normalize(tokens[tokens.length - 1])
    const selectedTokens = tokens
      .slice(0, -1)
      .map((token) => this.normalize(token))
      .filter(Boolean)

    const filteredOptions = sourceOptions
      .filter((option) => {
        const normalizedOption = this.normalize(option)

        if (selectedTokens.includes(normalizedOption)) {
          return false
        }

        return !currentToken || normalizedOption.includes(currentToken)
      })
      .slice(0, 100)

    datalistElement.innerHTML = ""

    filteredOptions.forEach((option) => {
      const suggestion = document.createElement("option")
      suggestion.value = this.buildCsvSuggestion(rawValue, option)
      datalistElement.appendChild(suggestion)
    })
  }

  buildCsvSuggestion(rawValue, suggestion) {
    const parts = (rawValue || "").split(",")

    if (parts.length <= 1) {
      return suggestion
    }

    const prefix = parts
      .slice(0, -1)
      .map((part) => part.trim())
      .filter(Boolean)
      .join(", ")

    return prefix ? `${prefix}, ${suggestion}` : suggestion
  }

  entryElements() {
    return this.element.querySelectorAll("[data-progress-entry='true']")
  }

  bucketElements() {
    return this.element.querySelectorAll("[data-progress-bucket]")
  }

  datalistValues(datalistElement) {
    return Array.from(datalistElement.options)
      .map((option) => option.value)
      .filter(Boolean)
  }

  selectedOptions(selectElement) {
    return Array.from(selectElement.selectedOptions).map((option) => this.normalize(option.value))
  }

  parseCsvTokens(rawValue) {
    return this.normalize(rawValue)
      .split(",")
      .map((value) => value.trim())
      .filter(Boolean)
  }

  parseEntryValues(rawValue) {
    return this.normalize(rawValue)
      .split("|")
      .map((value) => value.trim())
      .filter(Boolean)
  }

  unique(values) {
    return Array.from(new Set(values.filter(Boolean)))
  }

  normalize(value) {
    return (value || "").toString().trim().toLowerCase()
  }
}
