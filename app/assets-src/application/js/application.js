// Load turbo
import { Turbo } from "@hotwired/turbo-rails"
window.Turbo = Turbo
Turbo.config.drive.progressBarDelay = 200

// Load/Start stimulus application
import "./stimulus/application"

// Load bootstrap
import "bootstrap"

// Close open offcanvas panels before Turbo caches the page
import "./offcanvas_cleanup"


