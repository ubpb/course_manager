import { Controller } from "@hotwired/stimulus"

// Filters the options of a <select> by a case-insensitive substring match
// against a text input. Options are rebuilt (not hidden), because Safari
// does not reliably hide <option> elements.
export default class extends Controller {
  static targets = ["input", "select"]

  connect() {
    this.allOptions = Array.from(this.selectTarget.options).map((option) => ({
      value: option.value,
      text: option.text
    }))
  }

  filter() {
    const query = this.inputTarget.value.trim().toLowerCase()
    const selectedValue = this.selectTarget.value

    const matches = this.allOptions.filter((option) => option.text.toLowerCase().includes(query))

    this.selectTarget.innerHTML = ""

    for (const { value, text } of matches) {
      const option = new Option(text, value)
      option.selected = value === selectedValue
      this.selectTarget.add(option)
    }

    if (matches.length === 0) {
      const option = new Option("Keine Treffer", "")
      option.disabled = true
      this.selectTarget.add(option)
    }
  }
}
