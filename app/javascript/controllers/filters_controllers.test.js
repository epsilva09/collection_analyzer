import { describe, expect, test, vi } from "vitest"
import CompareTableFiltersController from "./compare_table_filters_controller"
import MaterialsFiltersController from "./materials_filters_controller"
import MaterialCollectionsFiltersController from "./material_collections_filters_controller"

function setTarget(controller, targetName, value) {
  const capitalized = targetName.charAt(0).toUpperCase() + targetName.slice(1)

  Object.defineProperty(controller, `${targetName}Target`, {
    value,
    configurable: true
  })

  Object.defineProperty(controller, `has${capitalized}Target`, {
    value: true,
    configurable: true
  })
}

function setValue(controller, valueName, value) {
  const capitalized = valueName.charAt(0).toUpperCase() + valueName.slice(1)

  Object.defineProperty(controller, `${valueName}Value`, {
    value,
    configurable: true
  })

  Object.defineProperty(controller, `has${capitalized}Value`, {
    value: true,
    configurable: true
  })
}

describe("compare_table_filters_controller", () => {
  test("filters rows by attribute and winner and clears inputs", () => {
    document.body.innerHTML = `
      <section id="compare-root">
        <input id="attr" value="" />
        <datalist id="attr-list">
          <option value="HP"></option>
          <option value="INT"></option>
        </datalist>
        <input id="winner" value="" />
        <datalist id="winner-list">
          <option value="A"></option>
          <option value="B"></option>
        </datalist>
        <span id="visible"></span>
        <span id="total"></span>
        <p id="summary"></p>

        <table>
          <tbody>
            <tr data-compare-row="true" data-compare-attribute-value="hp" data-compare-winner-value="a"></tr>
            <tr data-compare-row="true" data-compare-attribute-value="int" data-compare-winner-value="b"></tr>
          </tbody>
        </table>
      </section>
    `

    const controller = Object.create(CompareTableFiltersController.prototype)
    const root = document.getElementById("compare-root")

    Object.defineProperty(controller, "element", { value: root, configurable: true })
    setTarget(controller, "attributeInput", document.getElementById("attr"))
    setTarget(controller, "attributeDatalist", document.getElementById("attr-list"))
    setTarget(controller, "winnerInput", document.getElementById("winner"))
    setTarget(controller, "winnerDatalist", document.getElementById("winner-list"))
    setTarget(controller, "visibleCount", document.getElementById("visible"))
    setTarget(controller, "totalCount", document.getElementById("total"))
    setTarget(controller, "resultsSummary", document.getElementById("summary"))
    setValue(controller, "resultsTemplate", "Showing COUNT attributes")
    setValue(controller, "totalCount", 2)

    controller.connect()

    expect(document.getElementById("visible").textContent).toBe("2")

    controller.attributeInputTarget.value = "hp"
    controller.winnerInputTarget.value = "a"
    controller.applyFilters()

    const rows = Array.from(root.querySelectorAll("[data-compare-row='true']"))
    expect(rows[0].hidden).toBe(false)
    expect(rows[1].hidden).toBe(true)
    expect(document.getElementById("visible").textContent).toBe("1")

    controller.clearFilters()
    expect(controller.attributeInputTarget.value).toBe("")
    expect(controller.winnerInputTarget.value).toBe("")
    expect(rows[0].hidden).toBe(false)
    expect(rows[1].hidden).toBe(false)
  })
})

describe("materials_filters_controller", () => {
  test("filters by material and bucket and persists URL params", () => {
    document.body.innerHTML = `
      <section id="materials-root">
        <input id="material-input" value="" />
        <datalist id="material-list">
          <option value="Material A"></option>
          <option value="Material B"></option>
        </datalist>

        <input id="bucket-input" value="" />
        <datalist id="bucket-list">
          <option value="Near"></option>
          <option value="Low"></option>
        </datalist>

        <div id="material-chips"></div>
        <div id="bucket-chips"></div>
        <p id="summary"></p>
        <span id="visible"></span>
        <span id="total"></span>
        <div id="empty" hidden></div>

        <div data-materials-bucket="near">
          <span data-materials-count-badge="true"></span>
          <table><tbody>
            <tr id="row-1" data-materials-entry="true" data-material-name-values="material a" data-material-bucket-values="near"></tr>
          </tbody></table>
        </div>
        <div data-materials-bucket="low">
          <span data-materials-count-badge="true"></span>
          <table><tbody>
            <tr id="row-2" data-materials-entry="true" data-material-name-values="material b" data-material-bucket-values="low"></tr>
          </tbody></table>
        </div>
      </section>
    `

    const controller = Object.create(MaterialsFiltersController.prototype)
    const root = document.getElementById("materials-root")
    const replaceStateSpy = vi.spyOn(window.history, "replaceState")

    Object.defineProperty(controller, "element", { value: root, configurable: true })
    setTarget(controller, "materialInput", document.getElementById("material-input"))
    setTarget(controller, "materialDatalist", document.getElementById("material-list"))
    setTarget(controller, "materialChips", document.getElementById("material-chips"))
    setTarget(controller, "bucketInput", document.getElementById("bucket-input"))
    setTarget(controller, "bucketDatalist", document.getElementById("bucket-list"))
    setTarget(controller, "bucketChips", document.getElementById("bucket-chips"))
    setTarget(controller, "resultsSummary", document.getElementById("summary"))
    setTarget(controller, "visibleCount", document.getElementById("visible"))
    setTarget(controller, "totalCount", document.getElementById("total"))
    setTarget(controller, "emptyState", document.getElementById("empty"))
    setValue(controller, "resultsTemplate", "Showing COUNT materials")
    setValue(controller, "totalCount", 2)

    controller.connect()

    controller.materialInputTarget.value = "Material A"
    controller.bucketInputTarget.value = "Near"
    controller.applyFilters()

    expect(document.getElementById("row-1").hidden).toBe(false)
    expect(document.getElementById("row-2").hidden).toBe(true)
    expect(document.getElementById("visible").textContent).toBe("1")
    expect(replaceStateSpy).toHaveBeenCalled()

    const lastCall = replaceStateSpy.mock.calls[replaceStateSpy.mock.calls.length - 1]
    expect(lastCall[2]).toContain("f_material=Material+A")
    expect(lastCall[2]).toContain("f_bucket=Near")

    replaceStateSpy.mockRestore()
  })
})

describe("material_collections_filters_controller", () => {
  test("filters entries and persists collection params to URL", () => {
    document.body.innerHTML = `
      <section id="collections-root">
        <input id="collection-input" value="" />
        <datalist id="collection-list">
          <option value="Tier 1 Lago"></option>
          <option value="Tier 2 Castelo"></option>
        </datalist>

        <input id="bucket-input" value="" />
        <datalist id="bucket-list">
          <option value="Low"></option>
          <option value="Near"></option>
        </datalist>

        <p id="summary"></p>
        <span id="visible"></span>
        <span id="total"></span>
        <div id="empty" hidden></div>

        <table>
          <tbody>
            <tr id="collection-row-1" data-material-collections-entry="true" data-material-collections-name-values="tier 1 lago" data-material-collections-bucket-values="low"></tr>
            <tr id="collection-row-2" data-material-collections-entry="true" data-material-collections-name-values="tier 2 castelo" data-material-collections-bucket-values="near"></tr>
          </tbody>
        </table>
      </section>
    `

    const controller = Object.create(MaterialCollectionsFiltersController.prototype)
    const root = document.getElementById("collections-root")
    const replaceStateSpy = vi.spyOn(window.history, "replaceState")

    Object.defineProperty(controller, "element", { value: root, configurable: true })
    setTarget(controller, "collectionInput", document.getElementById("collection-input"))
    setTarget(controller, "collectionDatalist", document.getElementById("collection-list"))
    setTarget(controller, "bucketInput", document.getElementById("bucket-input"))
    setTarget(controller, "bucketDatalist", document.getElementById("bucket-list"))
    setTarget(controller, "resultsSummary", document.getElementById("summary"))
    setTarget(controller, "visibleCount", document.getElementById("visible"))
    setTarget(controller, "totalCount", document.getElementById("total"))
    setTarget(controller, "emptyState", document.getElementById("empty"))
    setValue(controller, "resultsTemplate", "Showing COUNT collections")
    setValue(controller, "totalCount", 2)

    controller.connect()

    controller.collectionInputTarget.value = "Tier 1"
    controller.bucketInputTarget.value = "Low"
    controller.applyFilters()

    expect(document.getElementById("collection-row-1").hidden).toBe(false)
    expect(document.getElementById("collection-row-2").hidden).toBe(true)
    expect(document.getElementById("visible").textContent).toBe("1")
    expect(replaceStateSpy).toHaveBeenCalled()

    const lastCall = replaceStateSpy.mock.calls[replaceStateSpy.mock.calls.length - 1]
    expect(lastCall[2]).toContain("f_collection=Tier+1")
    expect(lastCall[2]).toContain("f_bucket=Low")

    replaceStateSpy.mockRestore()
  })
})
