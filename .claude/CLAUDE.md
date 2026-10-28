# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Course/event manager for the University of Paderborn library (UB). Staff publish training **offers** and consultings, schedule **events** (termine), and manage participant **registrations**, certificates, and reports. Rails 8.1, Ruby (see `.ruby-version`). **The UI and URLs are in German** (`angebote`, `termine`, `anmeldung`); default locale is `:de`.

**Language:** everything in the repository is in English — code, comments, commit messages, docs — except `README.md`, which is German, and the German UI texts and mail templates.

## Commands

```bash
bin/setup                 # install deps, prepare DB, start server (idempotent)
bin/dev                   # start Rails server (thin wrapper around `rails server` — does NOT build JS)
bun run build:watch       # rebuild JS/CSS on change — run this ALONGSIDE bin/dev in a second terminal
bun run build             # one-off asset build → app/assets/builds/
bin/ci                    # CI: setup, rubocop, gem and JS audit, brakeman, tests, seeds (config/ci.rb)
bin/rails test            # run minitest suite
bin/rails test test/models/offer_test.rb              # single file
bin/rails test test/models/offer_test.rb:42           # single test by line
bin/rubocop               # lint (config: rubocop-ubpb rails.yml, see .rubocop.yml); -a for safe autocorrections
```

- **Database is MySQL/MariaDB** (`mysql2`, socket `/tmp/mysql.sock`; servers run MariaDB 11.8), the only database — no sqlite. Solid Queue's tables live in it too (no separate queue DB). Running `rake`/`bin/rails test` **regenerates the test DB from development** — don't point them at the same DB.

## Assets — non-standard

Propshaft + **Bun as the bundler** (not importmap or jsbundling). `bun.build.js` bundles `app/assets/src/application.js` → `app/assets/builds/`, including SCSS via the custom `bun.plugin.sass.js`. Because `bin/dev` only starts the Rails server, you must run `bun run build:watch` separately during development. Deploy (Capistrano) runs `bun install` + `bun run build` before `assets:precompile` (see `lib/capistrano/tasks/bun.rake`). Views are **Slim**; forms use **simple_form** + Bootstrap; JS behavior is **Stimulus** controllers in `app/assets/src/application/js/stimulus/`.

## Architecture

**Domain model** (`app/models/`):
- `Offer` — central entity, `type` is one of `Offer::TYPES`: `"course"`, `"consulting"`, `"self_study_course"`. STI is disabled (`self.inheritance_column = nil`) so `type` is a plain column; use the `course?`/`consulting?`/`self_study_course?` predicates and matching plural scopes. **Only `course` offers can have events** (enforced in admin `ContextHelpers` and frontend `prepare_event_context`); non-scheduled offers can instead set the `events_on_request` flag. Contact info and call-to-action text fall back to `ApplicationConfig` defaults (`default_contact`, `default_call_to_action`); a `before_save` nullifies attributes equal to the current default so the DB only stores genuine overrides. Archived offers stay out of the frontend and, unless filtered for, out of the admin offer list. Has many `events`, `topics`, `target_groups`.
- `Event` (termin) — belongs to an offer; has many `registrations`, one `report`, one `certification`. Rich scopes (`upcoming`/`past`/`published`/`from_published_offers`/`from_non_archived_offers`/`with_report`) and predicates (`full?`, `no_of_free_spaces`, `registration_closed?`). Reminder-mail fields (`email_from`, message) live on the event itself — the old `effective_*` fallback to the offer was removed.
- `Registration`, `Certification`/`Certificate`, `Report`, `Message`, `Topic`, `TargetGroup` (last two use `acts_as_list` with `reorder` routes).
- Email fields are validated against `ApplicationRecord::UPB_EMAIL_REGEXP` (must be `@ub.uni-paderborn.de` or blank).

**Controllers split into two namespaces:**
- `Frontend::` (`layout "frontend"`) — public site. **No user auth** (`current_user` is a `nil` TODO). The event show page was intentionally removed; events are rendered on the offer show page (`Frontend::OffersController#show`), and legacy `/kurse`, `/beratungen`, and `/termine` URLs 301-redirect via `old_id`.
- `Admin::` (`layout "admin"`) — staff area behind `authenticate!`. Login is via the **Alma API** (`alma_api` gem, `Admin::SessionsController`): validates user_id/password against Alma, only allows `STAFF` + `ACTIVE` users, stores `session[:current_admin_user_id]`. API key comes from `ApplicationConfig[:alma_api, :api_key]`.

**Routes are deeply nested** (`config/routes.rb`): `admin/offers → events → registrations`, plus per-event `report` and `certification` singular resources. Offers, events, and registrations have `bulk_process` collection actions (batch publish/unpublish etc.); events also have `bulk_move` (move between offers) — both driven from modals. A flat `admin/events` index exists across all offers (with XLSX `reports`). Frontend nests `events` (and their `registrations`) under `angebote`.

**Key shared concerns** (`app/controllers/concerns/`):
- `Filterable` — a `define_filter`/`filter_by` DSL for index pages. Filters are **persisted in `session`** per controller path; `?filter=...` sets them, `?reset_filter=...` clears them (both redirect). Instantiate with `create_filter(:name)`, then `@records = @filter.filter(scope)`. Used by both admin and frontend offer/event indexes.
- `NavScope` — threads a `nav_scope` param through all generated URLs (via `default_url_options`) to preserve list context in the admin.
- `Admin::ContextHelpers` — `prepare_offer_context` / `prepare_offer_event_context` / `..._registration_context` load `@offer`/`@event`/`@registration` and build breadcrumbs; called as `before_action`s. `Frontend::ApplicationController` has its own `prepare_offer_context`/`prepare_event_context` that scope to published + non-archived records.

**Config access:** `ApplicationConfig[:key, :subkey, default: ...]` reads `config/application.yml` (loaded via `config_for(:application)`), which supports `shared`/`development`/`production` sections and ERB (e.g. pulls Alma keys from Rails credentials). An env var named after the upcased, underscore-joined keys (e.g. `ENV["ALMA_API_API_KEY"]`) **overrides the file value**. Feature flags and defaults live here (`color_mode`, `locale_switching`, `default_contact`, `default_call_to_action`).

**Reports/documents:** `caxlsx_rails` for XLSX exports (admin event reports), `hexapdf` for certificate PDFs, `commonmarker`/`github-markup` for rendering markdown content.

**Mails:** grouped by recipient, not by trigger — `ParticipantMailer` (confirmation, cancellation_confirmation, reminder, change_notice, staff_message, certificate) and `TeamMailer` (new_registration, cancelled_registration). Plain-text only. Templates, partials and the mail layout live under `app/views/mailers/` (`ApplicationMailer` prepends that view path). Production delivers via sendmail with links to schulungen.ub.uni-paderborn.de; a server's `config/application.yml` may override both (`mail.delivery_method`, `mail.host`) — test systems use `letter_opener_web`, readable at `/admin/mail` — by logged in admins on servers, without login in development; the admin menu bar links it whenever mails go to `letter_opener_web`.

**Jobs:** Active Job runs on **Solid Queue** in production (development uses `:async`, tests `:test`). `config/recurring.yml` replaces the server crontab: `SendReminderMessagesJob` (daily 6am) and `DsgvoCleanupJob` (daily 5am), Berlin time; the rake tasks `app:mailer:send_reminder_messages` / `app:dsgvo:cleanup` run them by hand. On the servers `bin/jobs` runs as the systemd **user** service `course_manager-jobs` on the host with the Capistrano role `:jobs` (exactly one per stage); Capistrano checks, installs and restarts it on every deploy (`lib/capistrano/tasks/jobs.rake`). Each such server needs `loginctl enable-linger <deploy user>` once. **Anonymizing a stage:** `cap testing app:dsgvo:anonymize_all` anonymizes every registration and drops all queued jobs (refuses the production stage); stop the jobs service before and start it again afterwards.

## Testing

Minitest, run in parallel, without fixtures: each test creates its own records. Most behaviour is covered by integration tests per area (`test/integration/{admin,frontend,account}`), next to model, mailer, helper, job and rake task tests. A test reads like the existing ones: a comment above the class says what the area is for, the test names describe behaviour in plain English. Shared helpers live in `test/support/`:
- `AlmaAuthenticationStub` replaces the Alma calls of both logins (a valid staff user, a library user who is not staff, an inactive staff member); `AdminLogin#log_in_admin` signs in to the admin.
- `MailerRecords` builds the offer → event → registration chain (`create_offer`, `create_event`, `create_registration`); `ReportRecords#create_report` adds statistics.
- `ConfigOverride#with_config` replaces values of `config/application.yml` for a block, e.g. to switch on a feature flag.

No coverage tool is set up yet.
