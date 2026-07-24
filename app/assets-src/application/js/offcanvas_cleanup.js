import { Offcanvas } from "bootstrap"

// Bootstrap offcanvas is wired via data attributes only. Turbo snapshots the
// page as-is, so an open offcanvas would be restored open — but without a
// live Offcanvas instance, so it could no longer be closed (ESC/dismiss dead).
// Close it synchronously before Turbo caches the page (hide() animates, too
// slow for before-cache).
document.addEventListener("turbo:before-cache", () => {
  for (const element of document.querySelectorAll(".offcanvas.show, .offcanvas-lg.show")) {
    Offcanvas.getInstance(element)?.dispose()
    element.classList.remove("show", "showing", "hiding")
    element.removeAttribute("aria-modal")
    element.removeAttribute("role")
    element.style.removeProperty("visibility")
  }
  document.querySelectorAll(".offcanvas-backdrop").forEach((el) => el.remove())
  document.body.style.removeProperty("overflow")
  document.body.style.removeProperty("padding-right")
})
