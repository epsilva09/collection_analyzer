import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "text"]
  static values = {
    loadingText: String
  }

  handleSubmit() {
    if (!this.hasButtonTarget) {
      return
    }

    this.buttonTarget.disabled = true

    if (this.hasTextTarget && this.loadingTextValue) {
      this.textTarget.textContent = this.loadingTextValue
    }

    this.buttonTarget.classList.add("disabled")
    this.buttonTarget.setAttribute("aria-busy", "true")
  }
}
