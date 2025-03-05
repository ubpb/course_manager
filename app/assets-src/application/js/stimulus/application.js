import { Application } from "@hotwired/stimulus"

// Start Stimulus application
const application = Application.start()
export { application }

// Configure Stimulus development experience
application.debug = false
window.Stimulus   = application

// Register ColorModeSwitcher
import ColorModeSwitcher from "./color_mode_switcher.js"
application.register("color-mode-switcher", ColorModeSwitcher)

// Register Sortable controller
import Sortable from "@stimulus-components/sortable"
application.register("sortable", Sortable)

// Register CheckboxSelectAll controller
import CheckboxSelectAll from "@stimulus-components/checkbox-select-all"
application.register("checkbox-select-all", CheckboxSelectAll)
