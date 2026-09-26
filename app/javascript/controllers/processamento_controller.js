import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Safety net for queued processing (Etapa 0.3). The result normally arrives by
// broadcast, but one sent while the page was still (re)connecting to the cable
// is lost, leaving "Processando" on screen. While an arquivo is queued, this
// polls its state:
//   mode "card"    — fetches the gallery card as a turbo-stream and swaps it in;
//                    the new card only carries this controller if still queued.
//   mode "refresh" — asks for the state (JSON) and reloads the page once final.
export default class extends Controller {
  static values = { url: String, mode: { type: String, default: "refresh" }, interval: { type: Number, default: 2000 } }

  connect() {
    this.attempts = 0
    this._schedule()
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  _schedule() {
    // Give up after ~15 minutes; a reload then shows the real state.
    if (this.attempts++ > 450) return
    this.timer = setTimeout(() => this._check(), this.intervalValue)
  }

  _check() {
    if (this.modeValue === "card") return this._swapCard()
    fetch(this.urlValue, { headers: { Accept: "application/json" } })
      .then(r => r.json())
      .then(data => data.final ? Turbo.visit(window.location.href, { action: "replace" }) : this._schedule())
      .catch(() => this._schedule())
  }

  _swapCard() {
    fetch(this.urlValue, { headers: { Accept: "text/vnd.turbo-stream.html" } })
      .then(r => r.text())
      .then(html => Turbo.renderStreamMessage(html))
      .catch(() => this._schedule())
  }
}
