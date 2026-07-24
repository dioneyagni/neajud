import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  onChange(e) {
    const checkbox = e.target
    const url = checkbox.dataset.url
    const needsCut = checkbox.checked

    fetch(url, {
      method: "PATCH",
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
        "Accept": "text/html"
      },
      body: new URLSearchParams({ needs_cut: needsCut.toString() })
    }).then(() => {
      window.location.reload()
    })
  }
}
