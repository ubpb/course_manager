import { Controller } from "@hotwired/stimulus"
import { Modal } from "bootstrap"

// Opens a Bootstrap modal as soon as it enters the DOM (used for bulk action
// dialogs injected via Turbo Streams) and tears it down again on removal or
// before Turbo caches the page, so no backdrop is left behind.
export default class extends Controller {
  connect() {
    // Bootstrap appends the backdrop to <body>. If the modal itself lives
    // inside an ancestor that creates a stacking context, it paints behind
    // the backdrop — so re-parent it to <body> first. Moving the element
    // re-triggers connect(); the real setup happens on the second pass.
    if (this.element.parentElement !== document.body) {
      document.body.appendChild(this.element)
      return
    }

    this.modal = new Modal(this.element)

    this.element.addEventListener(
      "shown.bs.modal",
      () => this.element.querySelector("[autofocus]")?.focus(),
      { once: true }
    )

    // Dismissed without submitting: remove the re-parented element from <body>.
    this.element.addEventListener("hidden.bs.modal", () => this.element.remove(), { once: true })

    this.beforeCache = () => {
      this.teardown()
      this.element.remove()
    }
    document.addEventListener("turbo:before-cache", this.beforeCache)

    this.modal.show()
  }

  disconnect() {
    document.removeEventListener("turbo:before-cache", this.beforeCache)
    this.teardown()
  }

  teardown() {
    if (!this.modal) return

    const modal = this.modal
    this.modal = null

    modal.hide()
    modal.dispose()

    document.querySelectorAll(".modal-backdrop").forEach((element) => element.remove())
    document.body.classList.remove("modal-open")
    document.body.style.removeProperty("overflow")
    document.body.style.removeProperty("padding-right")
  }
}
