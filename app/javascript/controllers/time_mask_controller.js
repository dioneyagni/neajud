import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  connect() {
    this.formatOnLoad()
  }

  formatOnLoad() {
    const value = this.inputTarget.value
    if (value && !value.includes(":")) {
      this.inputTarget.value = this.secondsToHmm(parseInt(value, 10))
    }
  }

  format(event) {
    const raw = event.target.value.replace(/[^\d]/g, "")
    if (raw.length === 0) {
      event.target.value = ""
      return
    }

    let hours, mins
    if (raw.length <= 2) {
      hours = "0"
      mins = raw
    } else {
      hours = parseInt(raw.slice(0, -2), 10)
      mins = raw.slice(-2)
    }

    const clean = `${parseInt(hours, 10)}:${mins.padStart(2, "0")}`
    event.target.value = clean
  }

  secondsToHmm(seconds) {
    if (!seconds && seconds !== 0) return ""
    const h = Math.floor(seconds / 3600)
    const m = Math.floor((seconds % 3600) / 60)
    return `${h}:${String(m).padStart(2, "0")}`
  }
}
