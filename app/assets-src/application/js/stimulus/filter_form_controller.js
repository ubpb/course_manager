import { Controller } from "@hotwired/stimulus"

// Auto-submits the filter form when the user:
//   - toggles a checkbox/radio
//   - changes a <select> dropdown
//   - presses Enter in a text field
//
// Wiring is done via event delegation, so views only need to add
// `data-controller="filter-form"` to the <form>. No per-field markup.
export default class extends Controller {
  connect() {
    this.onChange = this.onChange.bind(this)
    this.onKeydown = this.onKeydown.bind(this)
    this.element.addEventListener("change", this.onChange)
    this.element.addEventListener("keydown", this.onKeydown)
  }

  disconnect() {
    this.element.removeEventListener("change", this.onChange)
    this.element.removeEventListener("keydown", this.onKeydown)
  }

  onChange(event) {
    const target = event.target
    if (target.matches("select, input[type=checkbox], input[type=radio]")) {
      this.submit()
    }
  }

  onKeydown(event) {
    if (event.key !== "Enter") return
    if (event.target.matches("input[type=text], input[type=search]")) {
      event.preventDefault()
      this.submit()
    }
  }

  submit() {
    this.element.requestSubmit()
  }
}
