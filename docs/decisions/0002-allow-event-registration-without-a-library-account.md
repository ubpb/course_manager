# 2. Allow event registration without a library account

- Status: Accepted
- Date: 2026-11-12

## Context

Registering for an event took a login with the library account. The login prefills the form from the library system,
and the account id it leaves on the registration links the registration to the participant's account: there they see
it, cancel it, find the access link of an online event and download their certificate. The id also kept a participant
from registering twice for one event, and its absence marked the registrations staff entered in the admin.

The team saw clearly fewer registrations than with the previous system, which took none. The reasons lie in how the
institution is organised, outside this application, but the login as a precondition was the hurdle that could be
removed.

## Decision

The registration form opens without a login. A box at the top of the form offers the login as an option, with what it
brings; after the login the visitor comes back to the form, prefilled. Logged in, the box names the user and offers the
logout, again back to the form.

A guest registration carries no account id and gets no self-service: the confirmation asks guests to reply to cancel,
and staff send certificates by mail, as for registrations entered in the admin. The access link of an online event
reaches guests through the confirmation, the reminder and the change notice, like everyone else.

A registration records its origin (`account`, `guest`, `admin`) in a column of its own instead of deriving it from the
account id. Registering twice for an event with the same email address is refused in the front end; the account id
check stays for logged-in users.

## Alternatives considered

- **A choice before the form** ("with library account" or "as a guest"). One more step for everyone, and it puts the
  login back in front of the form, which is what kept people away.
- **Login fields inside the registration form.** Two forms in one; failed logins, the rate limit and an unreachable
  library system would all have to be handled inside the modal, for little gain over the existing login page.
- **A personal link for guests** (a token in the mail leading to their registration, to cancel and to download the
  certificate). More self-service, but a second way into personal data and more to build; left for later should the
  mails prove too little.

## Consequences

- Anyone with an email address can register; the email address stays required.
- There is no protection against bots or spam: no captcha, no rate limit, no confirmation of the address. Anyone can
  make the application send a confirmation from the team's address, with a name of their choosing, to any address, and
  a notice to the team. The previous system worked the same way and saw no abuse. Should abuse start, a rate limit on
  registering or a confirmation link sent to the address come first.
- Guests cancel by mail and get certificates by mail; the team handles both by hand.
- The origin of a registration no longer depends on the account id and survives anonymizing. Registrations anonymized
  before the origin was recorded keep it unknown.
- No database constraint backs the email check, as anonymized registrations share one email; two requests at the same
  moment can leave a duplicate, which staff remove.
- A registration made as a guest does not appear in the account of the same person, even after a later login.
- "Einloggen" now names the login with the library account, "anmelden" only the registration for an event.
