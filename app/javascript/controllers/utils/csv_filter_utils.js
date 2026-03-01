export function normalizeToken(value) {
  return (value || "").toString().trim().toLowerCase()
}

export function parseRawCsvTokens(rawValue) {
  return (rawValue || "")
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean)
}

export function parseCsvTokens(rawValue) {
  return normalizeToken(rawValue)
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean)
}

export function buildCsvSuggestion(rawValue, suggestion) {
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

export function refreshCsvAutocompleteOptions({ inputElement, datalistElement, sourceOptions, maxOptions = 100 }) {
  const rawValue = inputElement.value || ""
  const tokens = rawValue.split(",").map((token) => token.trim())
  const currentToken = normalizeToken(tokens[tokens.length - 1])
  const selectedTokens = tokens
    .slice(0, -1)
    .map((token) => normalizeToken(token))
    .filter(Boolean)
  const selectedTokenSet = new Set(selectedTokens)

  const filteredOptions = sourceOptions
    .filter((option) => {
      const normalizedOption = normalizeToken(option)

      if (selectedTokenSet.has(normalizedOption)) {
        return false
      }

      return !currentToken || normalizedOption.includes(currentToken)
    })
    .slice(0, maxOptions)

  datalistElement.innerHTML = ""

  filteredOptions.forEach((option) => {
    const suggestion = document.createElement("option")
    suggestion.value = buildCsvSuggestion(rawValue, option)
    datalistElement.appendChild(suggestion)
  })
}

export function matchesAnyQuery(values, querySet, queryList) {
  return querySet.size === 0 || queryList.some((query) => values.some((value) => value.includes(query)))
}

export function uniqueDisplayTokens(values) {
  const seen = new Set()
  const result = []

  values.forEach((value) => {
    const normalized = normalizeToken(value)
    if (!normalized || seen.has(normalized)) {
      return
    }

    seen.add(normalized)
    result.push(value)
  })

  return result
}
