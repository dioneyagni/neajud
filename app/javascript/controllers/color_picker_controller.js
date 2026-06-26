import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "name"]

  select(event) {
    this.element.querySelectorAll(".color-swatch").forEach(s => s.classList.remove("selected"))
    event.currentTarget.classList.add("selected")
    this.inputTarget.value = event.currentTarget.dataset.id
    this.nameTarget.textContent = event.currentTarget.title
  }
}
