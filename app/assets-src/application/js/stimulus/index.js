import { application } from "./application"

//
// Register all controllers here
//

// ColorModeSwitcherController
import ColorModeSwitcherController from "./color_mode_switcher_controller.js"
application.register("color-mode-switcher", ColorModeSwitcherController)
