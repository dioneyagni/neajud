import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submit"]

  onSuccess(event) {
    if (event.detail.success) {
      const button = this.submitTarget
      const originalText = button.value
      button.value = "✓ Saved"
      button.disabled = true
      setTimeout(() => {
        button.value = originalText
        button.disabled = false
      }, 1500)
    }
  }
}