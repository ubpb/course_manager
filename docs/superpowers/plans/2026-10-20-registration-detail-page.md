# Anmeldungs-Detailseite + Mail-Verlinkung — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Detailseite `/account/anmeldungen/:id` für eigene Anmeldungen; alle Teilnehmer-Mails verlinken sie (nur bei Konto-Verknüpfung); Erinnerung enthält Zusatztext; Admin kann bei manueller Anlage Bestätigung senden.

**Architecture:** `show`-Action im bestehenden `Account::RegistrationsController` (Lookup über `find_registration`, scoped auf `ils_primary_id`). Mail-Varianten schalten zentral über `Registration#account_linked?` in Mail-Partials unter `app/views/application/mailers/`. Admin-Checkbox als Controller-Param.

**Tech Stack:** Rails 8.1, Slim, Bootstrap, Minitest (MySQL-Test-DB), Plain-Text-ERB-Mails.

**Spec:** `docs/superpowers/specs/2026-10-20-registration-detail-page-design.md`

## Global Constraints

- Tests: `bin/rails test` (gesamt) bzw. `bin/rails test <datei>`; **nie** `bin/rubocop` ausführen.
- UI/Mail-Texte deutsch; neue UI-Keys in `config/locales/de/account.yml` **und** `config/locales/en/account.yml`.
- Detail-URL in Mails: immer `account_registration_url(@registration)`, nie `account_root_url`.
- Test-Mail-Host: `http://example.com` → Detail-URL `http://example.com/account/anmeldungen/<id>`.
- Login in Tests: `post session_path, params: {login: {user_id: AlmaAuthenticationStub::VALID_USER_ID, password: AlmaAuthenticationStub::VALID_PASSWORD}}` → `ils_primary_id` `"12345"`. Admin analog mit `admin_session_path`.
- `MailerRecords#create_registration` legt Anmeldungen ohne `ils_primary_id` an (= nicht verknüpft); verknüpfte Fälle mit `create_registration(ils_primary_id: "12345")`.
- Mails: nie dreifache Zeilenumbrüche (`"\n\n\n"`) — in beiden Varianten.
- Commit-Messages enden mit:
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` und `Claude-Session: https://claude.ai/code/session_01PWPXMZ39tp67JQUtfVEBFM`

## Review Focus

1. Zusatztext mit HTML (`<script>…`) — Detailseite muss ihn escaped zeigen (Mail ist Plain Text; Seite darf nicht mehr rendern als Mail). → Test in Task 2.
2. Anonymisierte Anmeldung (`ils_primary_id` nil, Name „Gelöscht“) — Detailseite 404, Mails ohne Konto-Link. → Tests in Task 2 + 3 (nicht-verknüpft-Fälle decken es ab).
3. Termin heute, Uhrzeit schon vorbei — `event.upcoming?` ist ganztägig true → Abmelde-Button sichtbar, konsistent mit `destroy`. → Test in Task 2.
4. Admin-Create mit Validierungsfehler — keine Mail, Checkbox-Zustand bleibt erhalten. → Test in Task 4.
5. Termin ohne Ort/Dauer und ohne Zusatztext — Erinnerung ohne Leerblock, Detailseite ohne Hinweis-Box. → Tests in Task 2 + 3.

---

### Task 1: `Registration#account_linked?`

**Files:**
- Modify: `app/models/registration.rb`
- Test: `test/models/registration_test.rb` (neu)

**Interfaces:**
- Produces: `Registration#account_linked? -> Boolean` (`ils_primary_id.present?`)

- [ ] **Step 1: Failing test** — `RegistrationTest`:
  - `"a registration with an ILS id is linked to an account"` → `Registration.new(ils_primary_id: "12345").account_linked?` true
  - `"a registration without an ILS id is not linked"` → `nil` und `""` → false
- [ ] **Step 2:** `bin/rails test test/models/registration_test.rb` → FAIL (`NoMethodError`)
- [ ] **Step 3:** Methode in `registration.rb` nach `anonymized?`, kurzer Kommentar (manuell angelegt/anonymisiert → kein Konto).
- [ ] **Step 4:** Test → PASS
- [ ] **Step 5:** Commit `Add Registration#account_linked?`

---

### Task 2: Detailseite + Übersicht-Links

**Files:**
- Modify: `config/routes.rb:21` (`only: [:show, :destroy]`)
- Modify: `app/controllers/account/registrations_controller.rb` (`show`)
- Create: `app/views/account/registrations/show.html.slim`
- Create: `app/views/account/registrations/_notes.html.slim` (locals: `registration:`)
- Modify: `app/views/account/registrations/index.html.slim` (Titel → Detail-Link, beide Listen)
- Modify: `config/locales/de/account.yml`, `config/locales/en/account.yml` (`account.registrations.show.*`)
- Test: `test/integration/account/registration_show_test.rb` (neu)

**Interfaces:**
- Consumes: nichts aus Task 1 zwingend.
- Produces: Route-Helper `account_registration_path/url(registration)` → `/account/anmeldungen/:id` (Task 3, 4 nutzen `_url`).

- [ ] **Step 1: Failing tests** — `Account::RegistrationShowTest < ActionDispatch::IntegrationTest`. Setup: Offer (`title: "Literaturrecherche"`, `description: "Wir **suchen** Literatur."`, `learning_targets: "- Kataloge nutzen"`, published), Event `date_and_time: 1.week.from_now`, `online: true`, `online_url: "https://meet.example.com/abc"`, `duration: 90`, `confirmation_message: "###ANREDE###, bitte Zotero installieren."`; Registration mit `ils_primary_id: AlmaAuthenticationStub::VALID_USER_ID`, `internal_notes: "Intern: VIP"`, `user_notes: "Komme etwas später"`. Helper `log_in`. Tests:
  - `"the participant sees everything about the registration"`: 200; Body enthält `"Literaturrecherche"`, `"Hallo Max Mustermann, bitte Zotero installieren."`, `"<strong>suchen</strong>"`, `"Kataloge nutzen"`, `"90 Minuten"`, `href="https://meet.example.com/abc"`, `"Komme etwas später"`; enthält **nicht** `"Intern: VIP"`; `assert_select "form[action=?]", account_registration_path(@registration)` (Abmelden).
  - `"an unpublished and archived offer is still shown"`: Offer `published: false, archived: true`, Event `published: false` → 200; kein Link auf `frontend_offer_path(@offer)`.
  - `"a published offer links to its public page"`: `assert_select "a[href=?]", frontend_offer_path(@offer)`.
  - `"someone else's registration is not found"`: Registration mit `ils_primary_id: "99999"` → `assert_response :not_found`.
  - `"a registration without an account is not found"`: `ils_primary_id: nil` → 404.
  - `"a logged out visitor is sent to the login and back"`: `get` → `assert_redirected_to new_session_path`, `session[:return_to] == account_registration_path(@registration)`; `log_in` → `assert_redirected_to account_registration_path(@registration)`.
  - `"a past event offers the certificate instead of cancelling"`: Event `date_and_time: 3.days.ago`, `Certification.create!(event: @event, learning_results: "Katalogrecherche", signature: "Max Muster")` → kein Abmelde-Form, kein `meet.example.com`, `assert_select "a[href=?]", certificate_account_registration_path(@registration)`.
  - `"an event earlier today can still be cancelled"`: `date_and_time: Time.zone.now.beginning_of_day + 1.minute` (vorbei, aber heute) → Abmelde-Form da.
  - `"without a custom text there is no notes box"`: `confirmation_message: nil`, `location: nil`, `duration: nil` → 200, kein `".callout-warning"` (`assert_select ".callout-warning", 0`).
  - `"the custom text is escaped"`: `confirmation_message: "<script>alert(1)</script>"` → Body enthält nicht `"<script>alert(1)"`, enthält `"&lt;script&gt;"`.
  - `"the overview links each registration to its detail page"`: zweite eigene Anmeldung an vergangenem Event; `get account_root_path` → `assert_select "a[href=?]", account_registration_path(r)` für beide.
- [ ] **Step 2:** `bin/rails test test/integration/account/registration_show_test.rb` → FAIL (Routing/`AbstractController::ActionNotFound`)
- [ ] **Step 3: Route + `show`** — `def show`: `@registration = find_registration`, `@event`, `@offer`; `add_breadcrumb @offer.title`.
- [ ] **Step 4: Views** gemäß Spec „Layout (Variante A)“:
  - Termin-Karte: `render "frontend/events/details", event: @event, show_registration_info: false, show_online_url: @event.upcoming?`
  - `_notes`: nur wenn `registration.event.confirmation_message.present?`; Inhalt `simple_format(h(render_custom_message(...)))` in `.callout.callout-warning`.
  - Abmelden: `button_to … method: :delete, form: {data: {turbo_confirm: …}}` wie Index; Bescheinigung wie Index; öffentlicher Link nur `@offer.published? && !@offer.archived?`.
  - Kontakt/Beschreibung/Lernziele/CTA: Markup wie `frontend/offers/show.html.slim`.
  - Index: `link_to offer.title, account_registration_path(registration)` in beiden Listen (alte published-Verzweigung entfällt).
- [ ] **Step 5:** Locale-Keys de/en: `badge_upcoming` „Angemeldet“, `badge_past` „Vergangen“, `back` „Meine Anmeldungen“, `event` „Ihr Termin“, `notes` „Hinweise zu Ihrem Termin“, `description` „Beschreibung“, `learning_targets` „Lernziele“, `actions` „Aktionen“, `public_page` „Öffentliche Angebotsseite“, `registration` „Ihre Anmeldung“, `registered_at` „angemeldet am %{date}“, `field_of_interest` „Interessengebiet“, `user_notes` „Ihre Anmerkung“, `contact` „Kontakt“. Abmelden/Bestätigen/Bescheinigung: Index-Keys per absolutem Pfad wiederverwenden.
- [ ] **Step 6:** Test → PASS; `bin/rails test` gesamt grün.
- [ ] **Step 7:** Commit `Add registration detail page to the user account`

---

### Task 3: Mail-Partials + Templates

**Files:**
- Modify: `app/views/application/mailers/_cancel_info.text.erb` (2 Varianten)
- Create: `app/views/application/mailers/_registration_link.text.erb`
- Create: `app/views/application/mailers/_confirmation_message.text.erb`
- Modify: `app/views/frontend/mailers/registrations_mailer/confirmation.text.erb`
- Modify: `app/views/admin/mailers/events_mailer/reminder_message.text.erb`
- Modify: `app/views/admin/mailers/events_mailer/changed_notification.text.erb`
- Modify: `app/views/admin/mailers/registrations_mailer/user_message.text.erb`
- Modify: `app/views/admin/mailers/registrations_mailer/certificate.text.erb`
- Test: `test/mailers/frontend/registrations_mailer_test.rb`, `test/mailers/admin/events_mailer_test.rb`, `test/mailers/admin/registrations_mailer_test.rb`, `test/mailers/registration_mails_test.rb`

**Interfaces:**
- Consumes: `Registration#account_linked?` (Task 1), `account_registration_url` (Task 2).
- Produces: Partials `application/mailers/registration_link` und `application/mailers/confirmation_message` (lesen `@registration`, `@event`).

Texte (exakt):
- `LINKED_CANCEL` = `Alle Informationen zu Ihrer Anmeldung finden Sie jederzeit in Ihrem Benutzerkonto im Schulungs- und Beratungsportal. Sollten Sie den Termin nicht wahrnehmen können, melden Sie sich dort bitte rechtzeitig ab: <url>`
- `UNLINKED_CANCEL` = `Sollten Sie den Termin nicht wahrnehmen können, bitten wir Sie, uns dies rechtzeitig mitzuteilen. Antworten Sie dazu einfach auf diese E-Mail.`
- `REGISTRATION_LINK` = `Alle Informationen zu Ihrer Anmeldung finden Sie jederzeit in Ihrem Benutzerkonto: <url>`
- changed_notification Einleitung verknüpft: `… geändert haben. Weitere Details finden Sie in Ihrem Benutzerkonto im Schulungsportal unter <url>`; nicht verknüpft endet nach `… geändert haben.`

- [ ] **Step 1: Tests anpassen/ergänzen** (alle bestehenden `http://example.com/account`-Assertions ersetzen):
  - frontend `"the confirmation repeats offer, date and start time"`: statt Konto-Satz → `UNLINKED_CANCEL`, `assert_not_includes body, "/account"`.
  - frontend neu `"a linked confirmation points to the detail page"`: `create_registration(ils_primary_id: "12345", email: "erika@example.com")` → Body enthält `LINKED_CANCEL` mit `http://example.com/account/anmeldungen/#{r.id}`; `assert_not_includes body, "\n\n\n"`.
  - events_mailer: Erinnerung-Test → `UNLINKED_CANCEL`; neu `"a linked reminder points to the detail page"`; neu in `registration_mails_test.rb` `"the custom text is part of the reminder"` (`###ANREDE###, bitte Zotero installieren.` → `"Hallo Max Mustermann, bitte Zotero installieren."`) und `"a reminder without custom text has no gap"` (`location: nil` → kein `"\n\n\n"`); Kopfkommentar der Datei anpassen.
  - changed_notification: Zeilen 95/166/177 auf `UNLINKED_CANCEL` umstellen (`"auf diese E-Mail.\n\nTreffpunkt"`, `"auf diese E-Mail.\n\nVeranstaltungsform"`); `"klicken beim Termin auf"`-Negativ-Assertion → `assert_not_includes body, "nicht wahrnehmen"`; neu `"a linked change notice points to the detail page"` (Einleitung + Abmelde-Satz mit Detail-URL, kein `"\n\n\n"`); neu `"an unlinked change notice does not mention the account"` (`assert_not_includes body, "Benutzerkonto"`).
  - registrations_mailer: neu `"a linked user message points to the detail page"` / `"an unlinked user message does not"`; analog Zertifikat (`certify!` vorher).
- [ ] **Step 2:** `bin/rails test test/mailers` → FAIL an den neuen/angepassten Stellen.
- [ ] **Step 3: Partials** — `_cancel_info` verzweigt auf `@registration.account_linked?`; `_registration_link` rendert bei nicht verknüpft nichts und bringt eigene führende Leerzeile mit (Muster wie `_location_info`); `_confirmation_message` = bisheriger Inline-Block aus `confirmation.text.erb` (führende Leerzeile + `render_custom_message`).
- [ ] **Step 4: Templates** — confirmation: Inline-Block → Partial; reminder: `_confirmation_message` nach `_location_info`; changed_notification: Einleitung verzweigt; user_message: `_registration_link` nach `@message.body`; certificate: `_registration_link` nach Bescheinigungs-Satz. Jeweils vor `_footer`.
- [ ] **Step 5:** `bin/rails test test/mailers test/tasks` → PASS; gesamt grün.
- [ ] **Step 6:** Commit `Link mails to the registration detail page, drop account hints without account`

---

### Task 4: Admin — Vorschau + Bestätigung bei manueller Anlage

**Files:**
- Modify: `app/controllers/admin/offers/events_controller.rb` (`preview_confirmation_message`)
- Modify: `app/controllers/admin/offers/events/registrations_controller.rb` (`create`)
- Modify: `app/views/admin/offers/events/registrations/new.html.slim`
- Test: `test/integration/admin/event_confirmation_message_test.rb`, `test/integration/admin/manual_registration_test.rb` (neu)

**Interfaces:**
- Consumes: `account_linked?`, Partials aus Task 3.
- Produces: Param `send_confirmation` (`"1"`/`"0"`) im Admin-Create.

- [ ] **Step 1: Failing tests**
  - `event_confirmation_message_test.rb` `"the confirmation message is saved and shown in the preview"`: zusätzlich `assert_includes response.body, "/account/anmeldungen/0"`.
  - `Admin::ManualRegistrationTest` (Setup wie `event_confirmation_message_test.rb`, `include ActionMailer::TestHelper`):
    - `"the new form offers the confirmation checkbox, checked"`: `get new_admin_offer_event_registration_path(@offer, @event)` → `assert_select "input[type=checkbox][name=send_confirmation][checked]"`.
    - `"a manual registration sends the confirmation when asked"`: `assert_enqueued_emails 1 { post … params: {registration: {first_name:, last_name:, email:}, send_confirmation: "1"} }`; danach `perform_enqueued_jobs` bzw. Mail direkt bauen → Body enthält `UNLINKED_CANCEL`, nicht `"/account"`.
    - `"no confirmation without the checkbox"`: `send_confirmation: "0"` → `assert_no_enqueued_emails`.
    - `"an invalid registration sends nothing and keeps the choice"`: `first_name: ""`, `send_confirmation: "0"` → 422, `assert_no_enqueued_emails`, Checkbox **nicht** `checked`.
- [ ] **Step 2:** `bin/rails test test/integration/admin` → FAIL
- [ ] **Step 3:** Vorschau: Beispiel-`Registration.new(id: 0, ils_primary_id: "preview", …)`, Kommentar warum (Regelfall-Variante, URL braucht id).
- [ ] **Step 4:** `new.html.slim`: im `card-body` nach `_form_fields` Abschnitt mit `hidden_field_tag :send_confirmation, "0", id: nil` + `check_box_tag :send_confirmation, "1", params.fetch(:send_confirmation, "1") == "1", class: "form-check-input"` + Label „Anmeldebestätigung senden“ in `.form-check`. `create`: nach `save` `Frontend::Mailers::RegistrationsMailer.confirmation(@registration).deliver_later if params[:send_confirmation] == "1"`.
- [ ] **Step 5:** Tests → PASS; `bin/rails test` gesamt grün.
- [ ] **Step 6:** Commit `Let staff send the confirmation for manual registrations`

---

### Task 5: Abschluss

- [ ] **Step 1:** `bin/rails test` gesamt → 0 failures, 0 errors (Ausgabe festhalten).
- [ ] **Step 2:** Detailseite im Browser prüfen (Dev-Server im Worktree, eingeloggt, künftiger + vergangener Termin) — sofern lokal Login möglich; sonst im Bericht vermerken.
- [ ] **Step 3:** Branch-Review (superpowers:requesting-code-review), Findings fixen, committen.
