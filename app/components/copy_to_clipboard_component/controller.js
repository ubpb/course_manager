import { Controller } from "@hotwired/stimulus"

// Copies the value of the read only source field to the clipboard. The button
// confirms with "Kopiert" for a moment and then is ready to copy again; screen
// readers hear the outcome through the status region.
//
// Where the clipboard API is missing (it needs a secure context) the older
// execCommand("copy") on the selected text is tried. If that fails as well,
// the text stays selected so it can be copied by hand.
export default class extends Controller {
  static targets = ["source", "button", "idle", "copied", "status"]
  static values = { resetAfter: { type: Number, default: 2000 } }

  disconnect() {
    clearTimeout(this.resetTimeout)
  }

  select() {
    this.sourceTarget.select()
  }

  async copy() {
    const copied = (await this.writeToClipboard()) || this.copyBySelection()

    if (copied) {
      this.showCopied()
    } else {
      this.select()
      this.announce(this.statusTarget.dataset.failed)
    }
  }

  async writeToClipboard() {
    if (!navigator.clipboard?.writeText) return false

    try {
      await navigator.clipboard.writeText(this.sourceTarget.value)
      return true
    } catch {
      return false
    }
  }

  copyBySelection() {
    this.select()

    try {
      return document.execCommand("copy")
    } catch {
      return false
    }
  }

  showCopied() {
    this.idleTarget.hidden = true
    this.copiedTarget.hidden = false
    this.buttonTarget.classList.replace("btn-outline-primary", "btn-success")
    this.announce(this.statusTarget.dataset.copied)

    clearTimeout(this.resetTimeout)
    this.resetTimeout = setTimeout(() => this.reset(), this.resetAfterValue)
  }

  reset() {
    this.idleTarget.hidden = false
    this.copiedTarget.hidden = true
    this.buttonTarget.classList.replace("btn-success", "btn-outline-primary")
    this.announce("")
  }

  announce(message) {
    this.statusTarget.textContent = message
  }
}
