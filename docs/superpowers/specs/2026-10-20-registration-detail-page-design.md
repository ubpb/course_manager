# Detailseite einer Anmeldung im Benutzerkonto + Mail-Verlinkung

Datum: 2026-10-20 · Branch: `worktree-registration-detail-page`

## Warum

Die Anmeldebestätigung kann einen Zusatztext enthalten (`events.confirmation_message`,
z. B. „Zotero vorab installieren“). Sie geht aber sofort nach der Anmeldung raus,
der Termin liegt oft Wochen später. Die Erinnerungsmail kurz vor dem Termin hat nur
statischen Text. Wichtige Hinweise stecken damit in einer alten Mail, die keiner
mehr findet.

Lösung: Jede Anmeldung bekommt eine **Detailseite im Benutzerkonto** mit allen
Infos (Termin, Hinweise, Beschreibung, Lernziele, Kontakt). Alle Mails an
Teilnehmende verlinken dorthin. Zusätzlich nimmt die Erinnerungsmail den
Zusatztext direkt auf.

## Ziele

1. Neue Seite `GET /account/anmeldungen/:id` für eigene Anmeldungen, auch wenn
   Angebot/Termin unveröffentlicht oder archiviert ist.
2. Übersicht „Meine Anmeldungen“ verlinkt jede Anmeldung auf ihre Detailseite.
3. Mails an Teilnehmende mit Konto-Verknüpfung verlinken die Detailseite.
4. Mails an Teilnehmende **ohne** Konto-Verknüpfung (im Admin manuell angelegt,
   Altdaten) enthalten **keine** Konto-Links/-Hinweise mehr; Abmeldung dort per
   Antwort auf die Mail.
5. Erinnerungsmail enthält den Zusatztext (falls gepflegt).
6. Admin „Neuen Teilnehmer anlegen“: Checkbox „Anmeldebestätigung senden“,
   Standard **an** (bei vergangenen Terminen aus — Nachträge für Bescheinigungen).

## Nicht-Ziele

- Anzeige des **kompletten** Bestätigungstexts auf der Detailseite. Vorerst nur
  der Zusatztext; Entscheidung später. Deshalb steckt der Abschnitt in einem
  eigenen Partial, damit ein späterer Tausch lokal bleibt.
- Änderungen an Abmeldebestätigung (`cancellation_confirmation`, Anmeldung dort
  schon gelöscht) und Team-Mails (`notification`, `cancellation_notification`).
- Detailseiten/Konto für Personen ohne Bibliothekslogin.
- Konto-Verknüpfung nachträglich herstellen (z. B. `ils_primary_id` im Admin pflegen).

## Anti-Ziele

- Zugriff auf fremde Anmeldungen über die ID in der URL (IDOR). Fremde, gelöschte und
  anonymisierte IDs bekommen dieselbe Antwort: Redirect zur Übersicht mit Hinweis
  „Diese Anmeldung ist nicht (mehr) vorhanden.“ (statt englischer 404-Seite, da Mail-Links
  die Anmeldung überleben — Stornierung, Löschung, DSGVO-Anonymisierung 10 Tage nach Termin).
- Mails an Personen ohne Konto, die auf ein Konto verweisen.
- Überraschende Mails: Bestätigung bei manueller Anlage nur, wenn Checkbox gesetzt.

## Begriffe

- **Konto-verknüpft** = `Registration#account_linked?` → `ils_primary_id.present?`.
  Selbst angemeldete Personen haben eine `ils_primary_id`; im Admin angelegte und
  anonymisierte (DSGVO-Task setzt `nil`) nicht.

## Teil 1 — Detailseite

### Route + Controller

- `config/routes.rb`, Namespace `account`: `resources :registrations, only: [:show, :destroy], path: "anmeldungen"` → `account_registration_path(registration)`.
- `Account::RegistrationsController#show`: lädt über bestehendes `find_registration`
  (scoped auf `current_user.ils_primary_id`) → fremde/unbekannte ID = `ActiveRecord::RecordNotFound`
  → Redirect `account_root_path` mit Alert `account.registrations.show.not_found`.
  Kein Filter auf `published`/`archived`.
- Breadcrumb: „Mein Konto“ (existiert) › Angebotstitel.
- Nicht eingeloggt → `authenticate_user!` leitet zum Login, merkt Pfad in
  `session[:return_to]`, nach Login zurück zur Detailseite (existiert schon, nur testen).
- `includes` so, dass Offer + Certification ohne N+1 geladen sind (wie `find_registration` heute).

### Layout (Variante A, zwei Spalten wie öffentliche Angebotsseite)

View `app/views/account/registrations/show.html.slim`, Bootstrap-Klassen wie
`frontend/offers/show.html.slim` (`.col-xl-9.col-lg-8` / `.col-xl-3.col-lg-4`).

**Kopf:** `h3` Angebotstitel + Badge (`Angemeldet` grün bei `event.upcoming?`,
`Vergangen` grau bei `event.past?`); rechts Button „Meine Anmeldungen“ → `account_root_path`.

**Hauptspalte:**
1. Karte „Ihr Termin“: `render "frontend/events/details", event:, show_registration_info: false, show_online_url: event.upcoming?`.
2. Box „Hinweise zu Ihrem Termin“ (Partial `account/registrations/_notes`), nur wenn
   `event.confirmation_message.present?`. Inhalt:
   `simple_format(render_custom_message(event.confirmation_message, registration:))`
   — Text ist für Plain-Text-Mails gepflegt, daher `simple_format` (escaped, Zeilenumbrüche),
   **nicht** Markdown. Platzhalter (`###NAME###` …) werden mit Daten der Anmeldung ersetzt.
   Optik: `.callout.callout-warning` (Klasse existiert im Theme, `.callout-info` wird schon auf der Angebotsseite genutzt).
3. Karte mit „Beschreibung“ und „Lernziele“ via `render_markdown`, je nur wenn vorhanden;
   Call-to-Action-Button wie öffentliche Seite, wenn `offer.call_to_action?`.

**Sidebar** (Abschnitte mit `h5` + `hr` wie öffentliche Seite):
1. „Aktionen“:
   - künftig (`event.upcoming?`): `button_to` Abmelden → `account_registration_path` DELETE, mit Turbo-Confirm (gleiche Texte wie Übersicht).
   - vergangen + `registration.certificate_available?`: Download Teilnahmebescheinigung.
   - Link „Öffentliche Angebotsseite“ → `frontend_offer_path(offer)` nur wenn `offer.published? && !offer.archived?`.
   - Abschnitt entfällt, wenn keine Aktion greift.
2. „Ihre Anmeldung“: Name, E-Mail, „angemeldet am“ (`created_at`, Datum);
   `field_of_interest` und `user_notes` falls vorhanden. `internal_notes` **nie**.
3. „Kontakt“: `offer.contact_name/email/phone` (Default-Fallback ist im Model) wie öffentliche Seite.

Abmelden aus der Detailseite → bestehendes `destroy` → Redirect zur Übersicht (unverändert).

### Übersicht

`account/registrations/index.html.slim`: Titel in beiden Listen (anstehend + vergangen)
immer `link_to offer.title, account_registration_path(registration)`. Bisheriger Link
auf die öffentliche Angebotsseite entfällt (ist jetzt in der Detailseite).

### I18n

Neue Texte unter `account.registrations.show.*` in `config/locales/de/account.yml`
**und** `config/locales/en/account.yml` (beide Dateien existieren). Bestehende
Index-Keys für Abmelden/Bestätigung/Bescheinigung wiederverwenden oder unter `show`
duplizieren — Builder entscheidet.

## Teil 2 — Mails

### Model

`Registration#account_linked?` → `ils_primary_id.present?`.

### Partials (`app/views/application/mailers/`)

- `_cancel_info.text.erb` — zwei Varianten nach `@registration.account_linked?`:
  - verknüpft (Vorschlag): „Alle Informationen zu Ihrer Anmeldung finden Sie in Ihrem Benutzerkonto im Schulungs- und Beratungsportal. Sollten Sie den Termin nicht wahrnehmen können, melden Sie sich dort bitte rechtzeitig ab: <account_registration_url(@registration)>“
  - nicht verknüpft: „Sollten Sie den Termin nicht wahrnehmen können, bitten wir Sie, uns dies rechtzeitig mitzuteilen. Antworten Sie dazu einfach auf diese E-Mail.“
- Neu `_registration_link.text.erb` — nur bei verknüpft, sonst leer (bringt eigene
  Leerzeile mit, wie `_location_info`): „Alle Informationen zu Ihrer Anmeldung finden Sie in Ihrem Benutzerkonto: <url>“
- Neu `_confirmation_message.text.erb` — rendert `render_custom_message(@event.confirmation_message, registration: @registration)` mit führender Leerzeile, wenn vorhanden; ersetzt den Inline-Block in `confirmation.text.erb` und wird in `reminder_message.text.erb` wiederverwendet.

Alle URLs: `account_registration_url(@registration)` (nicht mehr `account_root_url`).

### Templates

| Mail | Änderung |
|---|---|
| `frontend/.../confirmation` | Zusatztext via neuem Partial (Inhalt unverändert); `_cancel_info` (neue Varianten) |
| `admin/.../reminder_message` | **Zusatztext** nach Ort-Info einfügen; `_cancel_info` (neue Varianten) |
| `admin/.../changed_notification` | Einleitungssatz: verknüpft → „Weitere Details finden Sie in Ihrem Benutzerkonto im Schulungsportal unter <Detail-URL>“; nicht verknüpft → Satz entfällt. Date-Block nutzt `_cancel_info` (neue Varianten) |
| `admin/.../user_message` | `_registration_link` nach Nachrichtentext, vor Footer |
| `admin/.../certificate` | `_registration_link` vor Footer |

Formulierungen sind Vorschläge; Leerzeilenstruktur der Mails soll sauber bleiben
(keine doppelten/fehlenden Leerzeilen in beiden Varianten — in Tests prüfen).

### Admin-Vorschau der Bestätigung

`Admin::Offers::EventsController#preview_confirmation_message` baut eine
ungespeicherte Beispiel-Anmeldung. Sie soll die **verknüpfte** Variante zeigen
(Regelfall): `ils_primary_id` mit Dummywert und `id: 0` setzen, damit die URL
generierbar ist (`/account/anmeldungen/0`). Beispiel-URL in der Vorschau ist ok.

### Admin: Bestätigung bei manueller Anlage

- `admin/offers/events/registrations/new.html.slim`: Checkbox „Anmeldebestätigung
  senden“ (angehakt bei künftigen, leer bei vergangenen Terminen), **nur** im New-Formular (nicht Edit, nicht in
  `_form_fields`, das beide nutzen). Als eigenes Param außerhalb des Models,
  z. B. `params[:send_confirmation]` via `check_box_tag` mit Hidden-Field „0“
  (Bootstrap-Markup passend zu simple_form). Bei Validierungsfehler bleibt der
  gewählte Zustand erhalten.
- `create`: nach erfolgreichem `save` und `send_confirmation == "1"` →
  `Frontend::Mailers::RegistrationsMailer.confirmation(@registration).deliver_later`.
  Keine Team-Notification. Flash-Text unverändert oder um „Bestätigung versendet“ ergänzt — Builder entscheidet.

## Tests (Minitest, MySQL-Test-DB)

Bestehende Konventionen: `test/support/mailer_records.rb`, Login via
`AlmaAuthenticationStub` (`VALID_USER_ID` = `"12345"` → `ils_primary_id` `"12345"`),
Frontend-Login per `post session_path`, Admin per `post admin_session_path`.

- **Model** `test/models/registration_test.rb`: `account_linked?` true/false.
- **Integration** `test/integration/account/registration_show_test.rb`:
  - eigene Anmeldung: 200, Titel, Termindaten, Hinweise mit ersetzten Platzhaltern, Beschreibung + Lernziele (Markdown gerendert);
  - Angebot unveröffentlicht + archiviert → trotzdem 200;
  - fremde Anmeldung (andere `ils_primary_id`), Anmeldung ohne `ils_primary_id`, gelöschte Anmeldung → Redirect Übersicht mit Hinweis;
  - ausgeloggt → Redirect Login, `session[:return_to]` = Detailpfad, nach Login zurück;
  - künftig online: Zugangslink sichtbar, Abmelde-Button da; vergangen: kein Zugangslink, kein Abmelden, Bescheinigungs-Link wenn verfügbar;
  - Link „Öffentliche Angebotsseite“ nur bei veröffentlicht + nicht archiviert;
  - ohne Zusatztext keine Hinweis-Box; `internal_notes` nie sichtbar;
  - Übersicht verlinkt Detailseite (anstehend + vergangen).
- **Mailer** (bestehende Tests anpassen + ergänzen): für Bestätigung, Erinnerung,
  Terminänderung, Nachricht, Zertifikat je verknüpft → enthält
  `http://example.com/account/anmeldungen/<id>`; nicht verknüpft → enthält kein
  `/account` und (wo Abmelde-Hinweis) den Antwort-Hinweis. Erinnerung enthält
  Zusatztext mit ersetzten Platzhaltern; ohne Zusatztext kein Leer-Block.
  Bestehende Assertions auf `http://example.com/account` (in `test/mailers/admin/events_mailer_test.rb`,
  `test/mailers/frontend/registrations_mailer_test.rb`) werden ersetzt: `MailerRecords#create_registration`
  legt Anmeldungen **ohne** `ils_primary_id` an → dort greift künftig die nicht verknüpfte Variante.
  Kopfkommentar in `test/mailers/registration_mails_test.rb` („the reminder is a fixed template“) anpassen.
- **Admin-Integration**: New-Formular hat Checkbox angehakt; Create mit Checkbox →
  1 Bestätigungsmail enqueued (ohne Konto-Link); ohne Checkbox → keine Mail;
  Vorschau-Test bleibt grün und zeigt Detail-URL.
- Gesamte Suite grün (`bin/rails test`). Rubocop **nicht** laufen lassen.

## Sonstiges

- `.gitignore`: `/.superpowers` aufnehmen (Brainstorming-Mockups).

## Eigene Entscheidungen (zur Durchsicht)

- Zugangslink auf Detailseite nur bei künftigen Terminen.
- Hinweise mit `simple_format`, nicht Markdown (Text ist für Plain-Text-Mails gepflegt).
- Detailseite zeigt keine Themen/Zielgruppen-Badges.
- „Ihre Anmeldung“ zeigt auch Interessengebiet und Anmerkungen der Person.
- Linked-Variante von `_cancel_info` kombiniert „alle Infos“ + Abmelden in einem Absatz mit einer URL; Bestätigung/Erinnerung brauchen damit keinen zusätzlichen Link-Absatz.
- Admin-Vorschau zeigt verknüpfte Variante mit Beispiel-URL `/account/anmeldungen/0`.
- Checkbox als Controller-Param, nicht als Model-Attribut.

## Nachträge (2026-10-21, nach Review)

- **Zugangslink nur noch auf der Detailseite.** Die öffentliche Angebotsseite zeigt ihn nicht
  mehr; der Button „Sie sind bereits angemeldet“ führt auf die Detailseite der Anmeldung
  (`Event#registration_for(user)` ersetzt `Event#user_registered?`). Auf der Detailseite steht
  er bei künftigen Online-Terminen als Button „Online-Termin beitreten“ plus Adresse zum
  Kopieren; ohne Link der Hinweis aus der Mail („Die Zugangsdaten erhalten Sie … separaten E-Mail“).
- **Löschhinweis bei vergangenen Terminen:** „Aus Datenschutzgründen wird Ihre Anmeldung
  10 Tage nach dem Termin gelöscht, also ab dem <Datum>.“, mit Bescheinigung zusätzlich
  „Bitte laden Sie Ihre Teilnahmebescheinigung bis dahin herunter.“ Frist als
  `Registration::RETENTION_PERIOD`, die auch `app:dsgvo:cleanup` nutzt.
- **Checkbox** „Anmeldebestätigung senden“ nur bei künftigen Terminen vorausgewählt.
- **Veraltete Links** (storniert/gelöscht/anonymisiert) und fremde IDs → Redirect zur Übersicht mit Hinweis.
- **Übersicht „Meine Anmeldungen“** (2026-10-21): pro Anmeldung Titel + `frontend/events/_details`;
  einzige Aktion „Details“ öffnet die Detailseite als Modal (`?modal=1` + Turbo Stream in
  `#registration-modal`, Muster wie das Anmeldeformular). Abmelden/Bescheinigung nur noch dort.
  Ohne Turbo bzw. aus Mails: volle Seite; Login-Rücksprung ohne `?modal`.
