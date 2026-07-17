import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "display", "hidden", "editor"]

  static values = {
    suffix: { type: String, default: "" },
    decimal: { type: Boolean, default: false }
  }

  connect() {
    this.update()
  }

  edit() {
    const clean = this.displayTarget.textContent.replace(this.suffixValue, "").trim()
    this.editorTarget.value = clean
    this.displayTarget.classList.add("range-slider-value--hidden")
    this.editorTarget.classList.remove("range-slider-editor--hidden")
    this.editorTarget.focus()
    this.editorTarget.select()
  }

  commit(event) {
    if (event.type === "keydown" && event.key !== "Enter") return
    event.preventDefault()
    this._applyEdit()
  }

  _applyEdit() {
    const min = parseFloat(this.inputTarget.min)
    const max = parseFloat(this.inputTarget.max)
    const step = parseFloat(this.inputTarget.step)
    let raw = this.editorTarget.value.replace(",", ".").trim()
    let num = parseFloat(raw)

    if (!isNaN(num)) {
      num = Math.min(max, Math.max(min, num))
      num = Math.round((num - min) / step) * step + min
      num = parseFloat(num.toFixed(10))
      this.inputTarget.value = num.toString()
      this.update()
    }

    this.editorTarget.classList.add("range-slider-editor--hidden")
    this.displayTarget.classList.remove("range-slider-value--hidden")
  }

  update() {
    let raw = this.inputTarget.value
    if (this.decimalValue) {
      raw = parseFloat(raw).toFixed(2).replace(".", ",")
    }
    const formatted = raw + this.suffixValue
    this.displayTarget.textContent = formatted
    this.hiddenTarget.value = formatted
  }
}
