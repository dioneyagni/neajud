import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["count"]

  connect() {
    document.addEventListener("pedido:item-added", this._updateCounter)
  }

  disconnect() {
    document.removeEventListener("pedido:item-added", this._updateCounter)
  }

  _updateCounter = (e) => {
    const total = e.detail.total_itens
    if (this.hasCountTarget) {
      this.countTarget.textContent = `(${total})`
      this.countTarget.classList.remove("header-pedido-counter--hidden")
    }
  }
}
