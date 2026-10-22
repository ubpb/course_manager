import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Sends what the surrounding form currently holds -- saved or not -- to a
// preview endpoint and renders the turbo stream it answers with: a modal with
// the mail. Unlike a submit button this never saves the form, and Enter in a
// text field keeps saving instead of previewing.
export default class extends Controller {
  async open({ currentTarget: button, params: { url } }) {
    const data = new FormData(this.element.closest("form"))
    // The edit form tunnels PATCH through _method; the preview is a POST.
    data.delete("_method")

    button.disabled = true

    try {
      const response = await fetch(url, {
        method: "POST",
        body: data,
        headers: {
          Accept: "text/vnd.turbo-stream.html",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
        },
        credentials: "same-origin"
      })

      if (!response.ok) throw new Error(`Preview failed with status ${response.status}`)

      Turbo.renderStreamMessage(await response.text())
    } catch (error) {
      console.error(error)
      window.alert("Die Vorschau konnte nicht geladen werden.")
    } finally {
      button.disabled = false
    }
  }
}
