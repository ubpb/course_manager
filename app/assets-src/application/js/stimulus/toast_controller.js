import { Controller } from "@hotwired/stimulus"
import { Toast } from "bootstrap"

// Shows a flash message of the admin as a Bootstrap toast (see
// admin/application/_toasts). Its data attributes say whether it hides by
// itself and when; Bootstrap holds the time while pointer or focus is on it.
// A hidden toast is removed, and so is every toast before Turbo caches the
// page, so "Back" does not show it again.
export default class extends Controller {
  connect() {
    // Without the fade: a toast removed while it fades (a quick click away,
    // a refresh) would have Bootstrap finish the transition on the disposed
    // instance and throw.
    this.toast = Toast.getOrCreateInstance(this.element, { animation: false })

    this.element.addEventListener("hidden.bs.toast", () => this.element.remove(), { once: true })

    this.beforeCache = () => this.element.remove()
    document.addEventListener("turbo:before-cache", this.beforeCache)

    this.toast.show()
  }

  disconnect() {
    document.removeEventListener("turbo:before-cache", this.beforeCache)
    this.toast?.dispose()
    this.toast = null
  }
}
