import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "statusInput",
    "statusDatalist",
    "statusMulti",
    "statusChips",
    "resultsSummary",
    "itemInput",
    "itemDatalist",
    "itemMulti",
    "itemChips"
  ]
  static values = {
    resultsTemplate: String
  }

  static PARAM_KEYS = {
    status: "f_status",
    item: "f_item",
    statusMulti: "f_status_multi",
    itemMulti: "f_item_multi"
  }

  connect() {
    this.loadFiltersFromUrl()
    this.entries = this.buildEntryCache()
    this.buckets = this.buildBucketCache()
    this.statusAutocompleteOptions = this.datalistValues(this.statusDatalistTarget)
    this.itemAutocompleteOptions = this.datalistValues(this.itemDatalistTarget)

    this.refreshStatusAutocomplete()
    this.refreshItemAutocomplete()
    this.applyFilters()
  }

  applyFilters() {
    const previousTop = this.statusInputTarget.getBoundingClientRect().top

    this.buckets.forEach((bucketData) => {
      bucketData.lastExpanded = this.isBucketExpanded(bucketData)
    })

    const statusQueries = this.unique([
      ...this.parseCsvTokens(this.statusInputTarget.value),
      ...this.selectedOptions(this.statusMultiTarget)
    ])
    const statusQuerySet = new Set(statusQueries)
    const statusQueryList = Array.from(statusQuerySet)

    const itemQueries = this.unique([
      ...this.parseCsvTokens(this.itemInputTarget.value),
      ...this.selectedOptions(this.itemMultiTarget)
    ])
    const itemQuerySet = new Set(itemQueries)
    const itemQueryList = Array.from(itemQuerySet)
    this.entries.forEach((entryData) => {
      const { element, statusValues, itemValues } = entryData

      const statusMatches =
        statusQuerySet.size === 0 ||
        statusQueryList.some((query) => statusValues.some((value) => value.includes(query)))

      const itemMatches =
        itemQuerySet.size === 0 ||
        itemQueryList.some((query) => itemValues.some((value) => value.includes(query)))

      element.hidden = !(statusMatches && itemMatches)
    })

    let visibleEntriesTotal = 0

    this.buckets.forEach((bucketData) => {
      const visibleEntries = bucketData.entries.filter((entry) => !entry.hidden).length
      visibleEntriesTotal += visibleEntries

      if (bucketData.badge) {
        bucketData.badge.textContent = visibleEntries
      }

      if (visibleEntries === 0) {
        bucketData.lastExpanded = this.isBucketExpanded(bucketData)
        bucketData.element.hidden = true
        this.setBucketExpanded(bucketData, false)
      } else {
        bucketData.element.hidden = false
        const shouldExpand = bucketData.lastExpanded !== undefined ? bucketData.lastExpanded : bucketData.initialExpanded
        this.setBucketExpanded(bucketData, shouldExpand)
      }
    })

    this.refreshStatusAutocomplete()
    this.refreshItemAutocomplete()
    this.renderChips()
    this.persistFiltersToUrl()
    this.renderResultsSummary(visibleEntriesTotal)

    const nextTop = this.statusInputTarget.getBoundingClientRect().top
    window.scrollBy(0, nextTop - previousTop)
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

  removeChip(event) {
    const chipType = event.currentTarget.dataset.chipType
    const chipValue = this.normalize(event.currentTarget.dataset.chipValue)

    if (!chipType || !chipValue) {
      return
    }

    if (chipType === "status") {
      this.removeToken(this.statusInputTarget, chipValue)
      this.deselectToken(this.statusMultiTarget, chipValue)
    }

    if (chipType === "item") {
      this.removeToken(this.itemInputTarget, chipValue)
      this.deselectToken(this.itemMultiTarget, chipValue)
    }

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
    return Array.from(this.element.querySelectorAll("[data-progress-entry='true']")).map((entry) => ({
      element: entry,
      statusValues: this.parseEntryValues(entry.dataset.progressStatusValues),
      itemValues: this.parseEntryValues(entry.dataset.progressMaterialValues)
    }))
  }

  buildBucketCache() {
    return Array.from(this.element.querySelectorAll("[data-progress-bucket]")).map((bucket) => ({
      element: bucket,
      badge: bucket.querySelector("[data-progress-count-badge='true']"),
      entries: Array.from(bucket.querySelectorAll("[data-progress-entry='true']")),
      collapseElement: bucket.querySelector(".accordion-collapse"),
      toggleButton: bucket.querySelector(".accordion-button"),
      initialExpanded: bucket.querySelector(".accordion-collapse")?.classList.contains("show") || false,
      lastExpanded: undefined
    }))
  }

  renderChips() {
    this.renderChipGroup(this.statusChipsTarget, this.activeTokens(this.statusInputTarget, this.statusMultiTarget), "status")
    this.renderChipGroup(this.itemChipsTarget, this.activeTokens(this.itemInputTarget, this.itemMultiTarget), "item")
  }

  renderResultsSummary(visibleEntriesTotal) {
    if (!this.hasResultsTemplateValue || !this.hasResultsSummaryTarget) {
      return
    }

    this.resultsSummaryTarget.textContent = this.resultsTemplateValue.replace("COUNT", visibleEntriesTotal.toString())
  }

  renderChipGroup(container, tokens, chipType) {
    container.innerHTML = ""

    tokens.forEach((token) => {
      const chip = document.createElement("button")
      chip.type = "button"
      chip.className = "btn btn-sm btn-outline-secondary progress-filter-chip"
      chip.dataset.action = "click->progress-filters#removeChip"
      chip.dataset.chipType = chipType
      chip.dataset.chipValue = token
      chip.textContent = `${token} ×`
      container.appendChild(chip)
    })
  }

  activeTokens(inputElement, selectElement) {
    const inputTokens = this.parseRawCsvTokens(inputElement.value)
    const selectedTokens = Array.from(selectElement.selectedOptions).map((option) => option.textContent.trim())
    return this.uniqueDisplayTokens([ ...inputTokens, ...selectedTokens ])
  }

  parseRawCsvTokens(rawValue) {
    return (rawValue || "")
      .split(",")
      .map((value) => value.trim())
      .filter(Boolean)
  }

  uniqueDisplayTokens(values) {
    const seen = new Set()
    const result = []

    values.forEach((value) => {
      const normalized = this.normalize(value)
      if (!normalized || seen.has(normalized)) {
        return
      }

      seen.add(normalized)
      result.push(value)
    })

    return result
  }

  removeToken(inputElement, tokenToRemove) {
    const remaining = this.parseRawCsvTokens(inputElement.value)
      .filter((token) => this.normalize(token) !== tokenToRemove)
    inputElement.value = remaining.join(", ")
  }

  deselectToken(selectElement, tokenToRemove) {
    Array.from(selectElement.options).forEach((option) => {
      const optionValue = this.normalize(option.value)
      const optionText = this.normalize(option.textContent)

      if (optionValue === tokenToRemove || optionText === tokenToRemove) {
        option.selected = false
      }
    })
  }

  isBucketExpanded(bucketData) {
    return bucketData.collapseElement?.classList.contains("show") || false
  }

  loadFiltersFromUrl() {
    const params = new URLSearchParams(window.location.search)

    this.statusInputTarget.value = params.get(this.constructor.PARAM_KEYS.status) || ""
    this.itemInputTarget.value = params.get(this.constructor.PARAM_KEYS.item) || ""

    this.applyMultiSelection(this.statusMultiTarget, params.get(this.constructor.PARAM_KEYS.statusMulti))
    this.applyMultiSelection(this.itemMultiTarget, params.get(this.constructor.PARAM_KEYS.itemMulti))
  }

  applyMultiSelection(selectElement, rawValue) {
    const selectedValues = this.parseCsvTokens(rawValue)
    const selectedSet = new Set(selectedValues)

    Array.from(selectElement.options).forEach((option) => {
      option.selected = selectedSet.has(this.normalize(option.value))
    })
  }

  persistFiltersToUrl() {
    const params = new URLSearchParams(window.location.search)

    this.persistParam(params, this.constructor.PARAM_KEYS.status, this.statusInputTarget.value)
    this.persistParam(params, this.constructor.PARAM_KEYS.item, this.itemInputTarget.value)
    this.persistParam(params, this.constructor.PARAM_KEYS.statusMulti, this.selectedOptions(this.statusMultiTarget).join(","))
    this.persistParam(params, this.constructor.PARAM_KEYS.itemMulti, this.selectedOptions(this.itemMultiTarget).join(","))

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

  setBucketExpanded(bucketData, expanded) {
    if (!bucketData.collapseElement || !bucketData.toggleButton) {
      return
    }

    bucketData.collapseElement.classList.remove("collapsing")
    bucketData.collapseElement.classList.add("collapse")
    bucketData.collapseElement.classList.toggle("show", expanded)

    bucketData.toggleButton.classList.toggle("collapsed", !expanded)
    bucketData.toggleButton.setAttribute("aria-expanded", expanded ? "true" : "false")
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
