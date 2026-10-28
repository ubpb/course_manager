import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "admin-nav"

// Leads the menu bar of the admin back to where staff left an area (see
// admin/application/_navbar): each page remembers itself for its area, and
// the links to the other areas lead to the pages remembered for them. The
// link of the current area keeps leading to its list. The pages are kept in
// the sessionStorage, so each tab has its own. The login page names no area
// and forgets them, so a new login starts from the lists.
export default class extends Controller {
  static targets = ["link"]
  static values = { section: String, path: String }

  connect() {
    if (!this.hasSectionValue) {
      this.forget()
      return
    }

    if (this.pathValue) this.remember({ ...this.read(), [this.sectionValue]: this.pathValue })
    this.resume()
  }

  // Also after a refresh, which morphs the links back to the lists.
  resume() {
    const paths = this.read()

    for (const link of this.linkTargets) {
      const section = link.dataset.adminNavSection
      if (section !== this.sectionValue && paths[section]) link.href = paths[section]
    }
  }

  // Without a sessionStorage (blocked, private mode) the links lead to the
  // lists as before.
  read() {
    try {
      return JSON.parse(sessionStorage.getItem(STORAGE_KEY)) ?? {}
    } catch {
      return {}
    }
  }

  remember(paths) {
    try {
      sessionStorage.setItem(STORAGE_KEY, JSON.stringify(paths))
    } catch {
      // see read()
    }
  }

  forget() {
    try {
      sessionStorage.removeItem(STORAGE_KEY)
    } catch {
      // see read()
    }
  }
}
