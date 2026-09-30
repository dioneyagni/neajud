import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  onChange(e) {
    const checkbox = e.target
    const url = checkbox.dataset.url
    const needsCut = checkbox.checked

    fetch(url, {
      method: "PATCH",
      headers: {
        // No meta tag in the test env (forgery protection off): reading
        // .content of null threw before the request (first E2E of the toggle,
        // Etapa 1.1, 3/5).
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || "",
        "Accept": "text/html"
      },
      body: new URLSearchParams({ needs_cut: needsCut.toString() })
    }).then(() => {
      window.location.reload()
    })
  }
}
