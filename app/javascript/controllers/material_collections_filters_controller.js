import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "collectionInput",
    "collectionDatalist",
    "bucketInput",
    "bucketDatalist",
    "filtersCard",
    "resultsSummary",
    "visibleCount",
    "totalCount",
    "emptyState"
  ]

  static values = {
    resultsTemplate: String,
    totalCount: Number
  }

  static PARAM_KEYS = {
    collection: "f_collection",
    bucket: "f_bucket"
  }

  connect() {
    this.handleResize = this.updateStickyOffset.bind(this)
    window.addEventListener("resize", this.handleResize)

    this.loadFiltersFromUrl()
    this.entries = this.buildEntryCache()
    this.collectionAutocompleteOptions = this.datalistValues(this.collectionDatalistTarget)
    this.bucketAutocompleteOptions = this.datalistValues(this.bucketDatalistTarget)

    this.refreshCollectionAutocomplete()
    this.refreshBucketAutocomplete()
    this.renderCounter(this.entries.length)
    this.applyFilters()
    this.updateStickyOffset()
  }

  disconnect() {
    if (this.handleResize) {
      window.removeEventListener("resize", this.handleResize)
    }
  }

  applyFilters() {
    const collectionQueries = this.parseCsvTokens(this.collectionInputTarget.value)
    const collectionQuerySet = new Set(collectionQueries)
    const collectionQueryList = Array.from(collectionQuerySet)

    const bucketQueries = this.parseCsvTokens(this.bucketInputTarget.value)
    const bucketQuerySet = new Set(bucketQueries)
    const bucketQueryList = Array.from(bucketQuerySet)

    this.entries.forEach((entryData) => {
      const { element, collectionValues, bucketValues } = entryData

      const collectionMatches =
        collectionQuerySet.size === 0 ||
        collectionQueryList.some((query) => collectionValues.some((value) => value.includes(query)))

      const bucketMatches =
        bucketQuerySet.size === 0 ||
        bucketQueryList.some((query) => bucketValues.some((value) => value.includes(query)))

      element.hidden = !(collectionMatches && bucketMatches)
    })

    const visibleEntriesTotal = this.entries.filter((entryData) => !entryData.element.hidden).length

    this.refreshCollectionAutocomplete()
    this.refreshBucketAutocomplete()
    this.renderResultsSummary(visibleEntriesTotal)
    this.renderCounter(visibleEntriesTotal)
    this.toggleEmptyState(visibleEntriesTotal)
    this.persistFiltersToUrl()
    this.updateStickyOffset()
  }

  clearFilters() {
    this.collectionInputTarget.value = ""
    this.bucketInputTarget.value = ""
    this.applyFilters()
  }

  refreshCollectionAutocomplete() {
    this.refreshAutocompleteOptions(
      this.collectionInputTarget,
      this.collectionDatalistTarget,
      this.collectionAutocompleteOptions
    )
  }

  refreshBucketAutocomplete() {
    this.refreshAutocompleteOptions(
      this.bucketInputTarget,
      this.bucketDatalistTarget,
      this.bucketAutocompleteOptions
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
    const selectedTokenSet = new Set(selectedTokens)

    const filteredOptions = sourceOptions
      .filter((option) => {
        const normalizedOption = this.normalize(option)

        if (selectedTokenSet.has(normalizedOption)) {
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

  buildEntryCache() {
    return Array.from(this.element.querySelectorAll("[data-material-collections-entry='true']")).map((entry) => ({
      element: entry,
      collectionValues: this.parseEntryValues(entry.dataset.materialCollectionsNameValues),
      bucketValues: this.parseEntryValues(entry.dataset.materialCollectionsBucketValues)
    }))
  }

  loadFiltersFromUrl() {
    const params = new URLSearchParams(window.location.search)

    this.collectionInputTarget.value = params.get(this.constructor.PARAM_KEYS.collection) || ""
    this.bucketInputTarget.value = params.get(this.constructor.PARAM_KEYS.bucket) || ""
  }

  persistFiltersToUrl() {
    const params = new URLSearchParams(window.location.search)

    this.persistParam(params, this.constructor.PARAM_KEYS.collection, this.collectionInputTarget.value)
    this.persistParam(params, this.constructor.PARAM_KEYS.bucket, this.bucketInputTarget.value)

    const search = params.toString()
    const nextUrl = `${window.location.pathname}${search ? `?${search}` : ""}${window.location.hash}`
    window.history.replaceState({}, "", nextUrl)
  }

  persistParam(params, key, value) {
    const normalizedValue = (value || "").toString().trim()

    if (normalizedValue) {
      params.set(key, normalizedValue)
    } else {
      params.delete(key)
    }
  }

  renderResultsSummary(visibleEntriesTotal) {
    if (!this.hasResultsTemplateValue || !this.hasResultsSummaryTarget) {
      return
    }

    this.resultsSummaryTarget.textContent = this.resultsTemplateValue.replace("COUNT", visibleEntriesTotal.toString())
  }

  renderCounter(visibleEntriesTotal) {
    const total = this.hasTotalCountValue ? this.totalCountValue : this.entries.length

    if (this.hasVisibleCountTarget) {
      this.visibleCountTarget.textContent = visibleEntriesTotal.toString()
    }

    if (this.hasTotalCountTarget) {
      this.totalCountTarget.textContent = total.toString()
    }
  }

  toggleEmptyState(visibleEntriesTotal) {
    if (!this.hasEmptyStateTarget) {
      return
    }

    this.emptyStateTarget.hidden = visibleEntriesTotal !== 0
  }

  updateStickyOffset() {
    if (!this.hasFiltersCardTarget) {
      return
    }

    const cardRect = this.filtersCardTarget.getBoundingClientRect()
    const cardStyles = window.getComputedStyle(this.filtersCardTarget)
    const stickyTop = parseFloat(cardStyles.top || "0")
    const rawOffset = Math.ceil(cardRect.height + stickyTop + 8)
    const stickyOffset = Math.min(rawOffset, 180)

    this.element.style.setProperty("--material-collections-sticky-offset", `${stickyOffset}px`)
  }

  datalistValues(datalistElement) {
    return Array.from(datalistElement.options)
      .map((option) => option.value)
      .filter(Boolean)
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

  normalize(value) {
    return (value || "").toString().trim().toLowerCase()
  }
}
