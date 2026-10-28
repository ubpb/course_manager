// The filter each tab remembers for each list (see Filterable): the list's key
// (its controller path) -> its canonical query, kept in the sessionStorage, so
// each tab has its own. Every request Turbo makes carries them in the header
// X-Filter-State, so that a plain list URL leads back to its filter -- except
// going back or forward, which shows a list as it was.
const STORAGE_KEY = "filters"
const HEADER = "X-Filter-State"

// The page shown came from back or forward: by a restore visit, or loaded in
// full from the history.
let fromHistory = performance.getEntriesByType("navigation")[0]?.type === "back_forward"

// Without a sessionStorage (blocked, private mode) the tab remembers nothing.
function read() {
  try {
    return JSON.parse(sessionStorage.getItem(STORAGE_KEY)) ?? {}
  } catch {
    return {}
  }
}

function write(filters) {
  try {
    sessionStorage.setItem(STORAGE_KEY, JSON.stringify(filters))
  } catch {
    // see read()
  }
}

// An empty query forgets the list's filter.
export function rememberFilter(key, query) {
  const filters = read()

  if (query) {
    filters[key] = query
  } else {
    delete filters[key]
  }
  write(filters)
}

export function hasFilter(key) {
  return Boolean(read()[key])
}

export function forgetFilters(prefix) {
  write(Object.fromEntries(Object.entries(read()).filter(([key]) => !key.startsWith(prefix))))
}

export function cameFromHistory() {
  return fromHistory
}

document.addEventListener("turbo:visit", (event) => {
  fromHistory = event.detail.action === "restore"
})

document.addEventListener("turbo:before-fetch-request", (event) => {
  if (!isRestoreVisitRequest(event)) event.detail.fetchOptions.headers[HEADER] = JSON.stringify(read())
})

// Turbo asks for the page of a visit before it announces the visit
// (turbo:visit), so ask the visit itself whether it goes back or forward.
function isRestoreVisitRequest(event) {
  const visit = window.Turbo.navigator.currentVisit

  return visit?.action === "restore" && visit.location.href === event.detail.url.href
}
