import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select"]
  static values = { versionId: Number, url: String }

  save() {
    const annotations = this.selectTargets.map(select => ({
      layer_name: select.closest(".layer-config-row").querySelector(".layer-name").textContent,
      color: select.closest(".layer-config-row").querySelector(".layer-color-code").textContent,
      annotation: select.value
    }))

    const form = document.createElement("form")
    form.method = "post"
    form.action = this.urlValue

    const hiddenMethod = document.createElement("input")
    hiddenMethod.type = "hidden"
    hiddenMethod.name = "_method"
    hiddenMethod.value = "patch"
    form.appendChild(hiddenMethod)

    const hiddenVersion = document.createElement("input")
    hiddenVersion.type = "hidden"
    hiddenVersion.name = "version_id"
    hiddenVersion.value = this.versionIdValue
    form.appendChild(hiddenVersion)

    annotations.forEach((a, i) => {
      ["layer_name", "color", "annotation"].forEach(key => {
        const input = document.createElement("input")
        input.type = "hidden"
        input.name = `layer_annotations[${i}][${key}]`
        input.value = a[key]
        form.appendChild(input)
      })
    })

    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content
    if (csrfToken) {
      const csrfInput = document.createElement("input")
      csrfInput.type = "hidden"
      csrfInput.name = "authenticity_token"
      csrfInput.value = csrfToken
      form.appendChild(csrfInput)
    }

    document.body.appendChild(form)
    form.submit()
  }
}