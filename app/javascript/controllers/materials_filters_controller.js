import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "materialInput",
    "materialDatalist",
    "materialChips",
    "bucketInput",
    "bucketDatalist",
    "bucketChips",
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
    material: "f_material",
    bucket: "f_bucket"
  }

  connect() {
    this.handleResize = this.updateStickyOffset.bind(this)
    window.addEventListener("resize", this.handleResize)

    this.loadFiltersFromUrl()
    this.entries = this.buildEntryCache()
    this.buckets = this.buildBucketCache()
    this.materialAutocompleteOptions = this.datalistValues(this.materialDatalistTarget)
    this.bucketAutocompleteOptions = this.datalistValues(this.bucketDatalistTarget)

    this.refreshMaterialAutocomplete()
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
    const materialQueries = this.parseCsvTokens(this.materialInputTarget.value)
    const materialQuerySet = new Set(materialQueries)
    const materialQueryList = Array.from(materialQuerySet)

    const bucketQueries = this.parseCsvTokens(this.bucketInputTarget.value)
    const bucketQuerySet = new Set(bucketQueries)
    const bucketQueryList = Array.from(bucketQuerySet)

    this.entries.forEach((entryData) => {
      const { element, materialValues, bucketValues } = entryData

      const materialMatches =
        materialQuerySet.size === 0 ||
        materialQueryList.some((query) => materialValues.some((value) => value.includes(query)))

      const bucketMatches =
        bucketQuerySet.size === 0 ||
        bucketQueryList.some((query) => bucketValues.some((value) => value.includes(query)))

      element.hidden = !(materialMatches && bucketMatches)
    })

    let visibleEntriesTotal = 0

    this.buckets.forEach((bucketData) => {
      const visibleEntries = bucketData.entries.filter((entry) => !entry.hidden).length
      visibleEntriesTotal += visibleEntries

      if (bucketData.badge) {
        bucketData.badge.textContent = visibleEntries
      }

      bucketData.element.hidden = visibleEntries === 0
    })

    this.refreshMaterialAutocomplete()
    this.refreshBucketAutocomplete()
    this.renderChips()
    this.renderResultsSummary(visibleEntriesTotal)
    this.renderCounter(visibleEntriesTotal)
    this.toggleEmptyState(visibleEntriesTotal)
    this.persistFiltersToUrl()
    this.updateStickyOffset()
  }

  clearFilters() {
    this.materialInputTarget.value = ""
    this.bucketInputTarget.value = ""
    this.applyFilters()
  }

  loadFiltersFromUrl() {
    const params = new URLSearchParams(window.location.search)

    this.materialInputTarget.value = params.get(this.constructor.PARAM_KEYS.material) || ""
    this.bucketInputTarget.value = params.get(this.constructor.PARAM_KEYS.bucket) || ""
  }

  persistFiltersToUrl() {
    const params = new URLSearchParams(window.location.search)

    this.persistParam(params, this.constructor.PARAM_KEYS.material, this.materialInputTarget.value)
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

  updateStickyOffset() {
    if (!this.hasFiltersCardTarget) {
      return
    }

    const cardRect = this.filtersCardTarget.getBoundingClientRect()
    const cardStyles = window.getComputedStyle(this.filtersCardTarget)
    const stickyTop = parseFloat(cardStyles.top || "0")
    const stickyOffset = Math.ceil(cardRect.height + stickyTop + 8)

    this.element.style.setProperty("--materials-sticky-offset", `${stickyOffset}px`)
  }

  removeChip(event) {
    const chipType = event.currentTarget.dataset.chipType
    const chipValue = this.normalize(event.currentTarget.dataset.chipValue)

    if (!chipType || !chipValue) {
      return
    }

    if (chipType === "material") {
      this.removeToken(this.materialInputTarget, chipValue)
    }

    if (chipType === "bucket") {
      this.removeToken(this.bucketInputTarget, chipValue)
    }

    this.applyFilters()
  }

  refreshMaterialAutocomplete() {
    this.refreshAutocompleteOptions(
      this.materialInputTarget,
      this.materialDatalistTarget,
      this.materialAutocompleteOptions
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
    return Array.from(this.element.querySelectorAll("[data-materials-entry='true']")).map((entry) => ({
      element: entry,
      materialValues: this.parseEntryValues(entry.dataset.materialNameValues),
      bucketValues: this.parseEntryValues(entry.dataset.materialBucketValues)
    }))
  }

  buildBucketCache() {
    return Array.from(this.element.querySelectorAll("[data-materials-bucket]"))
      .map((bucket) => ({
        key: bucket.dataset.materialsBucket,
        element: bucket,
        badge: bucket.querySelector("[data-materials-count-badge='true']"),
        entries: Array.from(bucket.querySelectorAll("[data-materials-entry='true']"))
      }))
  }

  renderChips() {
    this.renderChipGroup(this.materialChipsTarget, this.parseRawCsvTokens(this.materialInputTarget.value), "material")
    this.renderChipGroup(this.bucketChipsTarget, this.parseRawCsvTokens(this.bucketInputTarget.value), "bucket")
  }

  renderChipGroup(container, tokens, chipType) {
    container.innerHTML = ""

    this.uniqueDisplayTokens(tokens).forEach((token) => {
      const chip = document.createElement("button")
      chip.type = "button"
      chip.className = "btn btn-sm btn-outline-secondary progress-filter-chip"
      chip.dataset.action = "click->materials-filters#removeChip"
      chip.dataset.chipType = chipType
      chip.dataset.chipValue = token

      const iconClass = chipType === "material" ? "fas fa-cube" : "fas fa-layer-group"
      chip.ariaLabel = `Remove ${chipType} filter ${token}`
      chip.innerHTML = `<i class="${iconClass} chip-icon" aria-hidden="true"></i><span class="chip-label">${this.escapeHtml(token)}</span><span class="chip-close" aria-hidden="true">×</span>`
      container.appendChild(chip)
    })
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

  datalistValues(datalistElement) {
    return Array.from(datalistElement.options)
      .map((option) => option.value)
      .filter(Boolean)
  }

  parseRawCsvTokens(rawValue) {
    return (rawValue || "")
      .split(",")
      .map((value) => value.trim())
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

  normalize(value) {
    return (value || "").toString().trim().toLowerCase()
  }

  escapeHtml(value) {
    return (value || "")
      .toString()
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#39;")
  }
}
