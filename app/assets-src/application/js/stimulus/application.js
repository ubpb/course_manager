import { Application } from "@hotwired/stimulus"

// Start Stimulus application
const application = Application.start()
export { application }

// Configure Stimulus development experience
application.debug = false
window.Stimulus   = application

// Register sortable component
import Sortable from "@stimulus-components/sortable"
application.register("sortable", Sortable)
