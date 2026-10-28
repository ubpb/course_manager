import { Controller } from "@hotwired/stimulus"
import { cameFromHistory, forgetFilters, hasFilter, rememberFilter } from "../filter_state"

// Keeps the filter of a list in the tab's memory (filter_state.js): each list
// page remembers its query, an unfiltered one forgets it. A page that could not
// know the tab's filter (loaded in full at its plain URL) loads itself again
// through Turbo, which brings the filter along. That reload morphs the page, so
// the controller does not connect again and cannot reload once more. With
// `forget`, the element only forgets the filters of the lists whose keys start
// with it.
export default class extends Controller {
  static values = { key: String, query: String, restore: Boolean, forget: String }

  connect() {
    if (this.forgetValue) {
      forgetFilters(this.forgetValue)
      return
    }
    // A snapshot Turbo shows ahead of the page is not the list's state.
    if (document.documentElement.hasAttribute("data-turbo-preview")) return

    this.connected = true

    if (this.restoreValue && !cameFromHistory() && hasFilter(this.keyValue)) {
      window.Turbo.visit(window.location.href, { action: "replace" })
      return
    }
    this.remember()
  }

  disconnect() {
    this.connected = false
  }

  // A refresh morphs the list into its new state.
  queryValueChanged() {
    if (this.connected) this.remember()
  }

  remember() {
    rememberFilter(this.keyValue, this.queryValue)
  }
}
