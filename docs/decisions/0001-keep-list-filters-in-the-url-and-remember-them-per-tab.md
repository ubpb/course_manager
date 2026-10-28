# 1. Keep list filters in the URL and remember them per tab

- Status: Accepted
- Date: 2026-10-28

## Context

The list pages (offers and events in the admin, offers in the front end) can be filtered. The filters used to be
stored in the server session, one entry per list. A browser has one session, so all its tabs and windows shared one
filter per list: staff who filtered a list in one tab changed the same list in every other tab, and a reload showed
whatever another tab had set last.

Lists must still keep their filter while staff work: when they come back to a list through the menu bar, a back link
or the redirect after deleting or saving an entry, they expect the list filtered as they left it.

## Decision

The filter of a list lives in its URL, in a short canonical form (`?upcoming-or-past=upcoming&published=1&topics=3,5`).
The request URL is the only source the server filters by. Every other form of a filter (the `filter[...]` params of a
form, another order, unknown values) redirects to the canonical URL.

Each browser tab remembers the last filter of each list in its `sessionStorage` and sends what it remembers with every
request Turbo makes, in the header `X-Filter-State`. A plain list URL requested with a remembered filter redirects to
that filter, keeping the flash. A list loaded in full at its plain URL, whose request carries no header, loads itself
again through Turbo. Back and forward leave the header out and show a list as it was.

The server keeps no filter in the session, only a note for the one request after a reset.

## Alternatives considered

- **Session per tab id.** The tab sends an id from its `sessionStorage`; the server keeps the filters per id in the
  session. Reloads, downloads and every other request not made by Turbo carry no id, so they lose the filter; a
  duplicated tab copies the id and shares the filter again; the cookie session grows with each tab.
- **Clean URLs, filter only in the tab's memory.** URLs stay `/admin/offers`; the server reads the filter from the
  header alone. Every reload renders the unfiltered list first and then the filtered one, bookmarks and shared links
  carry no filter, and the back button cannot step through filters. A prototype showed the flash on reload.
- **A token in the URL** (encoded filter or the id of a stored one). Short, but unreadable, and a stored filter needs
  storage and breaks links once it is cleaned up.

## Consequences

- Tabs are independent. Reloads, bookmarks, shared links and the back button show the filter they were made with.
- The URL names and values of the filters are public interface: renaming one breaks bookmarks and links unless the old
  form keeps being accepted. Old `filter[...]` links keep working through the canonical redirect.
- Coming back to a plain list URL costs one redirect; submitting a filter form costs one redirect, as before.
- A plain list URL loaded without Turbo while the tab remembers a filter shows the unfiltered list briefly before the
  filtered one.
- A new tab starts with unfiltered lists; a closed tab forgets its filters.
