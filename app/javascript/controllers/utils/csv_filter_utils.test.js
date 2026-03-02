import { describe, expect, test } from "vitest"
import {
  buildCsvSuggestion,
  matchesAnyQuery,
  normalizeToken,
  parseCsvTokens,
  parseRawCsvTokens,
  refreshCsvAutocompleteOptions,
  uniqueDisplayTokens
} from "./csv_filter_utils"

describe("csv_filter_utils", () => {
  test("normalizeToken trims and downcases values", () => {
    expect(normalizeToken("  TeSt Value  ")).toBe("test value")
    expect(normalizeToken(null)).toBe("")
  })

  test("parseRawCsvTokens preserves original casing and trims", () => {
    expect(parseRawCsvTokens(" Alpha, Beta , ,GAMMA ")).toEqual(["Alpha", "Beta", "GAMMA"])
  })

  test("parseCsvTokens normalizes casing and trims", () => {
    expect(parseCsvTokens(" Alpha, Beta , ,GAMMA ")).toEqual(["alpha", "beta", "gamma"])
  })

  test("buildCsvSuggestion appends suggestion to existing CSV prefix", () => {
    expect(buildCsvSuggestion("alpha, b", "beta")).toBe("alpha, beta")
    expect(buildCsvSuggestion("", "alpha")).toBe("alpha")
  })

  test("refreshCsvAutocompleteOptions filters by current token and selected prefix", () => {
    document.body.innerHTML = `
      <input id=\"token-input\" value=\"alpha, be\" />
      <datalist id=\"token-options\"></datalist>
    `

    const inputElement = document.getElementById("token-input")
    const datalistElement = document.getElementById("token-options")

    refreshCsvAutocompleteOptions({
      inputElement,
      datalistElement,
      sourceOptions: ["alpha", "beta", "delta"]
    })

    const options = Array.from(datalistElement.options).map((option) => option.value)

    expect(options).toEqual(["alpha, beta"])
  })

  test("matchesAnyQuery returns true when any value contains a query", () => {
    const values = ["alpha", "beta"]
    const querySet = new Set(["ta"])
    const queryList = Array.from(querySet)

    expect(matchesAnyQuery(values, querySet, queryList)).toBe(true)
    expect(matchesAnyQuery(values, new Set(["zz"]), ["zz"])).toBe(false)
  })

  test("uniqueDisplayTokens deduplicates case-insensitively while preserving first label", () => {
    expect(uniqueDisplayTokens(["Alpha", "alpha", "BETA", "beta"]))
      .toEqual(["Alpha", "BETA"])
  })
})
