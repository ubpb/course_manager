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

// Register FilterForm controller
import FilterForm from "./filter_form_controller.js"
application.register("filter-form", FilterForm)

// Register SelectFilter controller
import SelectFilter from "./select_filter_controller.js"
application.register("select-filter", SelectFilter)

// Register Modal controller
import ModalController from "./modal_controller.js"
application.register("modal", ModalController)

// Register Toast controller
import ToastController from "./toast_controller.js"
application.register("toast", ToastController)

// Register Tooltip controller
import TooltipController from "./tooltip_controller.js"
application.register("tooltip", TooltipController)

// Register MailPreview controller
import MailPreviewController from "./mail_preview_controller.js"
application.register("mail-preview", MailPreviewController)

// Register AdminNav controller
import AdminNavController from "./admin_nav_controller.js"
application.register("admin-nav", AdminNavController)

// Register RowLink controller
import RowLinkController from "./row_link_controller.js"
application.register("row-link", RowLinkController)

// Register the sidecar controllers of view components (app/components)
import CopyToClipboardComponentController from "../../../../components/copy_to_clipboard_component/controller.js"
application.register("copy-to-clipboard-component", CopyToClipboardComponentController)

