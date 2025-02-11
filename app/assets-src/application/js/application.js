// Load turbo
import { Turbo } from "@hotwired/turbo-rails"
window.Turbo = Turbo
Turbo.config.drive.progressBarDelay = 200

// Load stimulus controllers from ./stimulus/index.js
import "./stimulus/"

// Load bootstrap
import "bootstrap"


