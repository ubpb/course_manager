import { Controller } from "@hotwired/stimulus"

// Opens a URL when a table row is clicked, like the link in its first cell.
// Clicks on controls inside the row (checkbox, links, the actions menu) and in
// cells marked with data-row-link-ignore, clicks with a modifier key and
// selecting text keep their usual behavior.
export default class extends Controller {
  static values = { url: String }

  visit(event) {
    if (event.defaultPrevented || event.button !== 0) return
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return
    if (event.target.closest("a, button, input, label, select, textarea, .dropdown, [data-row-link-ignore]")) return
    if (window.getSelection().toString() !== "") return

    window.Turbo.visit(this.urlValue)
  }
}
