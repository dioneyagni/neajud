// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// A modal <dialog> still open when Turbo renders (a redirect back to the same
// page, a morph refresh) lost its `open` attribute but stayed in the top
// layer: the whole page went inert and every click landed on <html> until a
// reload (creating a molde from the arte page's dialog, 29/09/2026). Close
// them for real before any render.
document.addEventListener("turbo:before-render", () => {
  document.querySelectorAll("dialog[open]").forEach((dialog) => dialog.close())
})
