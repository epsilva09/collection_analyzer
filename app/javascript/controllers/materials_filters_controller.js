import { Controller } from "@hotwired/stimulus"
import {
  matchesAnyQuery,
  normalizeToken,
  parseCsvTokens,
  parseRawCsvTokens,
  refreshCsvAutocompleteOptions,
  uniqueDisplayTokens
} from "controllers/utils/csv_filter_utils"

export default class extends Controller {
  static targets = [
    "materialInput",
    "materialDatalist",
    "materialChips",
    "bucketInput",
    "bucketDatalist",
    "bucketChips",
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
    this.loadFiltersFromUrl()
    this.entries = this.buildEntryCache()
    this.buckets = this.buildBucketCache()
    this.materialAutocompleteOptions = this.datalistValues(this.materialDatalistTarget)
    this.bucketAutocompleteOptions = this.datalistValues(this.bucketDatalistTarget)

    this.refreshMaterialAutocomplete()
    this.refreshBucketAutocomplete()
    this.renderCounter(this.entries.length)
    this.applyFilters()
  }

  applyFilters() {
    const materialQueries = parseCsvTokens(this.materialInputTarget.value)
    const materialQuerySet = new Set(materialQueries)
    const materialQueryList = Array.from(materialQuerySet)

    const bucketQueries = parseCsvTokens(this.bucketInputTarget.value)
    const bucketQuerySet = new Set(bucketQueries)
    const bucketQueryList = Array.from(bucketQuerySet)

    this.entries.forEach((entryData) => {
      const { element, materialValues, bucketValues } = entryData

      const materialMatches = matchesAnyQuery(materialValues, materialQuerySet, materialQueryList)

      const bucketMatches = matchesAnyQuery(bucketValues, bucketQuerySet, bucketQueryList)

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
    refreshCsvAutocompleteOptions({
      inputElement,
      datalistElement,
      sourceOptions
    })
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
    this.renderChipGroup(this.materialChipsTarget, parseRawCsvTokens(this.materialInputTarget.value), "material")
    this.renderChipGroup(this.bucketChipsTarget, parseRawCsvTokens(this.bucketInputTarget.value), "bucket")
  }

  renderChipGroup(container, tokens, chipType) {
    container.innerHTML = ""

    uniqueDisplayTokens(tokens).forEach((token) => {
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

  parseEntryValues(rawValue) {
    return this.normalize(rawValue)
      .split("|")
      .map((value) => value.trim())
      .filter(Boolean)
  }

  removeToken(inputElement, tokenToRemove) {
    const remaining = parseRawCsvTokens(inputElement.value)
      .filter((token) => this.normalize(token) !== tokenToRemove)
    inputElement.value = remaining.join(", ")
  }

  normalize(value) {
    return normalizeToken(value)
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
