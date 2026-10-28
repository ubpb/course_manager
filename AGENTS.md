# AGENTS.md

How work is done in this repository, for coding agents and for people. The [README](README.md) (German) describes
setup, deployment and configuration; this file describes the application, the process and the rules on top of them.

## The project

Course/event manager for the University of Paderborn library (UB). Staff publish training **offers** and consultings, schedule **events** (termine), and manage participant **registrations**, certificates, and reports. Rails 8.1, Ruby (see `.ruby-version`). **The UI and URLs are in German** (`angebote`, `termine`, `anmeldung`); default locale is `:de`.

## Sizing the work

| Size | For example | How |
|---|---|---|
| Quick | a typo, wording, a comment | Change it and run the checks. |
| Bug | wrong behaviour, a crash | Reproduce it with a failing test first, then fix it. |
| Small change | a new option, a message, a small refactoring | Agree on it in the conversation, then test first. No spec, no plan. |
| Project | a feature, a new area of the application, a change across components | The full process below. |

When unsure, take the larger size. Work that grows while it is done moves up a size. Every size works in a worktree
(see [Git](#git)); the final review belongs to projects, and your human partner may ask for one on smaller work.

## The full process

The person who directs the work (superpowers calls them "your human partner") approves the design section by section,
then the spec, then the plan. From the approved plan on, the work runs to the end without stopping: implementation,
review, fixes, report. The [superpowers](https://github.com/obra/superpowers) skills named in each phase carry out
the phases; where a skill and this file differ, this file wins.

1. **Design** (`brainstorming`). Find out what is wanted and why before proposing anything. Ask one question per
   message. Propose two or three approaches with a recommendation, with code previews where they help, and compare
   with similar tools where that helps. Present the design in sections; your human partner approves each section.
2. **Spec**: `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`. It opens with the date, the branch and its base
   commit, the status and the ADRs it builds on, if any. Section 1 holds the context, goals, non-goals, success
   criteria and the decisions taken, and says whether one of them calls for an [ADR](#decisions); the last sections
   cover tests, documentation and what is deferred. Your human partner approves the spec before planning starts.
3. **Plan** (`writing-plans`): `docs/superpowers/plans/YYYY-MM-DD-<topic>.md`. It names global constraints, a review
   focus (the spots most likely to go wrong), amendments to the spec found while planning, and tasks that are each
   one commit, test first. Your human partner approves the plan.
4. **Implementation** (`using-git-worktrees`, `test-driven-development`, `executing-plans`). Work in a worktree. Per
   task: a failing test, the code, the passing test, `bin/rubocop`, a commit. Keep a progress ledger in
   `.superpowers/`. A deviation from the plan or the spec goes back into the document. When your human partner picks
   `subagent-driven-development` instead, its review after each task comes on top of the final review.
5. **Review** (`requesting-code-review`, `receiving-code-review`). At the end, a fresh reviewer on the most capable
   model available reviews the whole branch against the spec and the plan. Check each finding before acting on it,
   and push back with reasons on a wrong one. Fix every Critical and Important finding, each test first. List the
   Minor findings in the report as deferred; fixing them is recommended, and your human partner decides. Record in the
   spec what the review changed.
6. **Finish** (`verification-before-completion`, `finishing-a-development-branch`). After `bun run build`, `bin/ci`
   is green (its system tests run against the built assets). Report the result, the fixed findings and the deferred
   minors to your human partner. Merging and pushing follow the rules under [Git](#git).

Spec and plan are working documents: git ignores `docs/superpowers/`, and they go with the worktree. Do not commit
them, not even with `git add -f`, although the `brainstorming` skill says to commit the spec. What lasts is in the
code and its tests, the docs, the commit messages and, for a central decision, an [ADR](#decisions). An open question
in design or planning can be settled with a throwaway prototype; what it teaches goes into the spec, the prototype is
not kept.

Gates: no code before the plan is approved, and no claim that something works or is done without a green run whose
output you have seen. Your human partner may waive single approvals for one piece of work ("confirm the plan
yourself"); that holds for this work only.

## Decisions

A central decision gets an Architecture Decision Record (ADR): `docs/decisions/NNNN-<title>.md`, numbered from 0001.
Central means that it shapes the project for a long time and that someone would otherwise ask again why: the
architecture, a concept of the domain model, a dependency that is hard to replace, an approach that was dropped but
keeps coming up. Most decisions are not central; their why goes into the commit message.

- The spec says whether the work takes a central decision, and your human partner decides. The ADR is written in the
  branch that carries out the decision and is reviewed with it.
- An ADR is short, about a page. Its title states the decision; it gives the status and the date, the context, the
  decision, the alternatives considered and why they lost, and the consequences.
- An accepted ADR is not rewritten. A change of mind gets a new ADR, and the old one's status becomes "Superseded by
  NNNN".
- ADRs are public like the rest of the repository.

## Engineering rules

- Test everything: new and changed code is covered by tests, lines and branches (see [Testing](#testing)). No
  coverage tool is set up yet, so no threshold is enforced.
- RuboCop with `rubocop-ubpb` (`rails.yml`, see `.rubocop.yml`), run through `bin/rubocop`.
- Prefer current best practice and modern Ruby and Rails over the style of older code.

## Conventions

- Everything in the repository is in English: code, comments, commit messages, docs, ADRs — except `README.md`, which
  is German, and the German UI texts and mail templates. Specs and plans are in English too.
- Docs change with the code, in the same branch: the README and this file.
- A changed dependency changes lockfiles: commit every changed one (`Gemfile.lock`, `bun.lock`).
- One commit per topic. The subject is a sentence in the imperative that says what changes, without a type prefix or
  a final period ("Lead the admin menu back to the page last seen in an area"). The body says why, when the subject
  does not.

## Git

- Features are developed in parallel, each in its own worktree and branch.
- Work in a worktree under `.claude/worktrees/<name>` (ignored), created from `master`; Claude Code names its branch
  `worktree-<name>`. A new worktree lacks the ignored `config/master.key`: copy it from the main checkout. Set it up
  with `bin/setup --skip-server`, `bun install` and `bun run build`, and check the baseline with `bin/ci`.
- All worktrees share the development and test databases of `config/database.yml`: run the tests of one worktree at
  a time, and keep in mind that a migration run in one worktree changes the databases of all of them.
- Never push and never merge unless your human partner asks for it; until then, worktree branches stay local.
- Keep the history of `master` linear. To merge a branch, rebase it onto the current `master` (never merge `master`
  into a branch), run `bin/ci` on the rebased head, then fast-forward `master` with `git merge --ff-only`. The
  branch's commits are kept, one per topic: no merge commits, no squashing.
- The maintainer merges into `master`. Contributors without push rights push their branch to a fork and open a pull
  request; CI runs on pull requests and on `master`.
- Pull requests are merged the same way. The maintainer may squash a pull request whose commits are not one per topic.

## Commands

```bash
bin/setup                 # install deps, prepare DB, start server (idempotent)
bin/dev                   # start Rails server (thin wrapper around `rails server` — does NOT build JS)
bun run build:watch       # rebuild JS/CSS on change — run this ALONGSIDE bin/dev in a second terminal
bun run build             # one-off asset build → app/assets/builds/
bin/ci                    # CI: setup, rubocop, gem and JS audit, brakeman, tests, system tests, seeds (config/ci.rb)
bin/rails test            # run minitest suite (without system tests)
bin/rails test:system     # run system tests in headless Chrome (needs built assets)
bin/rails test test/models/offer_test.rb              # single file
bin/rails test test/models/offer_test.rb:42           # single test by line
bin/rubocop               # lint (config: rubocop-ubpb rails.yml, see .rubocop.yml); -a for safe autocorrections
```

- **Database is MySQL/MariaDB** (`mysql2`, socket `/tmp/mysql.sock`; servers run MariaDB 11.8), the only database — no sqlite. Solid Queue's tables live in it too (no separate queue DB). Running `rake`/`bin/rails test` **regenerates the test DB from development** — don't point them at the same DB.

## Assets — non-standard

Propshaft + **Bun as the bundler** (not importmap or jsbundling). `bun.build.js` bundles `app/assets-src/application.js` → `app/assets/builds/`, including SCSS via the custom `bun.plugin.sass.js`. Because `bin/dev` only starts the Rails server, you must run `bun run build:watch` separately during development. Deploy (Capistrano) runs `bun install` + `bun run build` before `assets:precompile` (see `lib/capistrano/tasks/bun.rake`). Views are **Slim**; forms use **simple_form** + Bootstrap; JS behavior is **Stimulus** controllers in `app/assets-src/application/js/stimulus/`.

## Architecture

**Domain model** (`app/models/`):
- `Offer` — central entity, `type` is one of `Offer::TYPES`: `"course"`, `"consulting"`, `"self_study_course"`. STI is disabled (`self.inheritance_column = nil`) so `type` is a plain column; use the `course?`/`consulting?`/`self_study_course?` predicates and matching plural scopes. **Only `course` offers can have events** (enforced in admin `ContextHelpers` and frontend `prepare_event_context`); non-scheduled offers can instead set the `events_on_request` flag. Contact info and call-to-action text fall back to `ApplicationConfig` defaults (`default_contact`, `default_call_to_action`); a `before_save` nullifies attributes equal to the current default so the DB only stores genuine overrides. Archived offers stay out of the frontend and, unless filtered for, out of the admin offer list. Has many `events`, `topics`, `target_groups`.
- `Event` (termin) — belongs to an offer; has many `registrations`, one `report`, one `certification`. Rich scopes (`upcoming`/`past`/`published`/`from_published_offers`/`from_non_archived_offers`/`with_report`) and predicates (`full?`, `no_of_free_spaces`, `registration_closed?`). Reminder-mail fields (`email_from`, message) live on the event itself — the old `effective_*` fallback to the offer was removed.
- `Registration`, `Certification`/`Certificate`, `Report`, `Message`, `Topic`, `TargetGroup` (last two use `acts_as_list` with `reorder` routes).
- Email fields are validated against `ApplicationRecord::UPB_EMAIL_REGEXP` (must be `@ub.uni-paderborn.de` or blank).

**Controllers split into two namespaces:**
- `Frontend::` (`layout "frontend"`) — public site. **No user auth** (`current_user` is a `nil` TODO). The event show page was intentionally removed; events are rendered on the offer show page (`Frontend::OffersController#show`), and legacy `/kurse`, `/beratungen`, and `/termine` URLs 301-redirect via `old_id`.
- `Admin::` (`layout "admin"`) — staff area behind `authenticate!`. Login is via the **Alma API** (`alma_api` gem, `Admin::SessionsController`): validates user_id/password against Alma, only allows `STAFF` + `ACTIVE` users, stores the user's Alma primary ID in a signed cookie of its own (`:admin_user`, path `/admin`), not in the session, which the front end shares and rotates on its own login. API key comes from `ApplicationConfig[:alma_api, :api_key]`. A record that is gone (`ActiveRecord::RecordNotFound`, e.g. a page the menu bar of another tab still leads to) redirects with 303 and an alert to the list of the page's area (`admin_menu_section`).

**Routes are deeply nested** (`config/routes.rb`): `admin/offers → events → registrations`, plus per-event `report` and `certification` singular resources. Offers, events, and registrations have `bulk_process` collection actions (batch publish/unpublish etc.); events also have `bulk_move` (move between offers) — both driven from modals. A flat `admin/events` index exists across all offers (with XLSX `reports`). Frontend nests `events` (and their `registrations`) under `angebote`.

**Key shared concerns** (`app/controllers/concerns/`):
- `Filterable` — a `define_filter`/`filter_by` DSL for index pages. Filters are **persisted in `session`** per controller path; `?filter=...` sets them, `?reset_filter=...` clears them (both redirect). Instantiate with `create_filter(:name)`, then `@records = @filter.filter(scope)`. Used by both admin and frontend offer/event indexes.
- `NavScope` — threads a `nav_scope` param through all generated URLs (via `default_url_options`) to preserve list context in the admin.
- `Admin::ContextHelpers` — `prepare_offer_context` / `prepare_offer_event_context` / `..._registration_context` load `@offer`/`@event`/`@registration` and build breadcrumbs; called as `before_action`s. `Frontend::ApplicationController` has its own `prepare_offer_context`/`prepare_event_context` that scope to published + non-archived records.
- `Admin::ModalForm` — admin forms that open in a modal over their list. The list links `new`/`edit` with `data-turbo-stream` and holds an empty `#<name>-modal` (`<name>` = `controller_name.singularize.dasherize`); `respond_with_modal` replaces it with the `_modal` partial, which renders `_form` (root `#<name>-form.modal-content`). `respond_with_errors` replaces only `#<name>-form` (replacing the modal would open a second one), `respond_with_list` answers with `turbo_stream.refresh(scroll: "preserve")`, which reloads whichever list is open, closes the modal and keeps the scroll position (set on the stream, not as a page meta, so other actions that redirect to the list still scroll up to their notice). Without Turbo, `new`/`edit` are pages whose forms submit with `data-turbo=false`.

**Config access:** `ApplicationConfig[:key, :subkey, default: ...]` reads `config/application.yml` (loaded via `config_for(:application)`), which supports `shared`/`development`/`production` sections and ERB (e.g. pulls Alma keys from Rails credentials). An env var named after the upcased, underscore-joined keys (e.g. `ENV["ALMA_API_API_KEY"]`) **overrides the file value**. Feature flags and defaults live here (`color_mode`, `locale_switching`, `default_contact`, `default_call_to_action`).

**Reports/documents:** `caxlsx_rails` for XLSX exports (admin event reports), `hexapdf` for certificate PDFs, `commonmarker`/`github-markup` for rendering markdown content.

**Admin menu bar:** its links to the other areas lead back to the page last seen there. The navbar names the area of each page (`admin_menu_section`) and the path to come back to (`admin_menu_resume_path`: the request path with its `nav_scope`; none for the answer to a form, such as one sent back with errors). The Stimulus controller `admin-nav` keeps one path per area in the `sessionStorage`, so each tab has its own, and points the links there. The link of the current area still leads to its list, a refresh (morph) gets the remembered links again, and the login page names no area and forgets them.

**Flash messages:** the admin shows them as toasts at the top right (`admin/application/_toasts`, rendered by `layouts/admin` right after the navbar): a sticky anchor of zero height, so they move nothing and stay at the top of the window when scrolled. `AdminToastHelper` maps the types to colors; `success`/`notice` hide after 5 s (paused under pointer or focus), `alert`/`error` stay until closed. The Stimulus controller `toast` hands each to Bootstrap's `Toast` (without Bootstrap's fade, see its comment; the toasts slide in by animate.css instead) and removes it once hidden or before Turbo caches the page. A form page that keeps its message at the form renders `alerts` itself, which takes it out of the flash before the layout renders (the admin login, the offer choice of a new event). The front end keeps `alerts` in the flow.

**Mails:** grouped by recipient, not by trigger — `ParticipantMailer` (confirmation, cancellation_confirmation, reminder, change_notice, staff_message, certificate) and `TeamMailer` (new_registration, cancelled_registration). Plain-text only. Templates, partials and the mail layout live under `app/views/mailers/` (`ApplicationMailer` prepends that view path). Production delivers via sendmail with links to schulungen.ub.uni-paderborn.de; a server's `config/application.yml` may override both (`mail.delivery_method`, `mail.host`) — test systems use `letter_opener_web`, readable at `/admin/mail` — by logged in admins on servers, without login in development; the admin menu bar links it whenever mails go to `letter_opener_web`.

**Jobs:** Active Job runs on **Solid Queue** in production (development uses `:async`, tests `:test`). `config/recurring.yml` replaces the server crontab: `SendReminderMessagesJob` (daily 6am) and `DsgvoCleanupJob` (daily 5am), Berlin time; the rake tasks `app:mailer:send_reminder_messages` / `app:dsgvo:cleanup` run them by hand. On the servers `bin/jobs` runs as the systemd **user** service `course_manager-jobs` on the host with the Capistrano role `:jobs` (exactly one per stage); Capistrano checks, installs and restarts it on every deploy (`lib/capistrano/tasks/jobs.rake`). Each such server needs `loginctl enable-linger <deploy user>` once. **Anonymizing a stage:** `cap testing app:dsgvo:anonymize_all` anonymizes every registration and drops all queued jobs (refuses the production stage); stop the jobs service before and start it again afterwards.

## Testing

Minitest, run in parallel, without fixtures: each test creates its own records. Most behaviour is covered by integration tests per area (`test/integration/{admin,frontend,account}`), next to model, mailer, helper, job and rake task tests. A test reads like the existing ones: a comment above the class says what the area is for, the test names describe behaviour in plain English. Shared helpers live in `test/support/`:
- `AlmaAuthenticationStub` replaces the Alma calls of both logins (a valid staff user, a library user who is not staff, an inactive staff member); `AdminLogin#log_in_admin` signs in to the admin.
- `MailerRecords` builds the offer → event → registration chain (`create_offer`, `create_event`, `create_registration`); `ReportRecords#create_report` adds statistics.
- `ConfigOverride#with_config` replaces values of `config/application.yml` for a block, e.g. to switch on a feature flag.
- `TurboStreamRequests::TURBO_STREAM_HEADERS` requests what Turbo asks for with `data-turbo-stream`, e.g. the modal of a form (`get new_admin_offer_path, headers: TURBO_STREAM_HEADERS`). `assert_select` reaches into the `<template>` of a `<turbo-stream>`.

System tests (`test/system`, headless Chrome via Selenium) cover what only a browser shows, such as modals and other JavaScript behaviour. `bin/rails test` leaves them out; `bin/rails test:system` runs them against the built assets, so run `bun run build` first. `ApplicationSystemTestCase#log_in_admin` signs in through the login form, with Alma stubbed out as above. `collect_script_errors` records the script errors of the current page and `script_errors` reads them; `wait_for_transitions` waits out Bootstrap's fade (a modal ignores a close while it is still opening, so wait for it to have the focus first).

## Claude Code

- `CLAUDE.md` imports this file, so Claude Code reads it whatever its version. Rules go into this file, not into
  `CLAUDE.md`. Personal instructions go into `CLAUDE.local.md` (ignored) or `~/.claude/CLAUDE.md`.
- `.claude/settings.json` turns on the superpowers plugin from the official marketplace but does not install it.
  Install it once with `/plugin install superpowers@claude-plugins-official`.
- Auto memory is personal. A rule for everyone belongs in this file.
