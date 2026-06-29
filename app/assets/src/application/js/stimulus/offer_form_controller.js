import { Controller } from "@hotwired/stimulus"

// Toggles the course-specific and consulting-specific field sections of the
// offer form based on the selected `type` radio. Used only on the "new" form;
// on "edit" the type is locked and only the matching section is rendered, so
// there are no type radios and connect() leaves the server-rendered state.
export default class extends Controller {
  static targets = ["type", "course", "consulting"]

  connect() {
    this.toggle()
  }

  toggle() {
    const selected = this.selectedType()
    if (!selected) return

    this.courseTargets.forEach(el => el.hidden = selected !== "course")
    this.consultingTargets.forEach(el => el.hidden = selected !== "consulting")
  }

  selectedType() {
    const checked = this.typeTargets.find(input => input.checked)
    return checked ? checked.value : null
  }
}
