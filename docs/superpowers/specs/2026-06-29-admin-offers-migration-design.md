# Admin Offers Migration — Design

Date: 2026-06-29
Branch: `refactor`

## Goal

Migrate the admin area from the separate `Course` / `Consulting` models to the
unified `Offer` model, mirroring the frontend migration already done in commit
`16b83f5`. Create a single `Admin::OffersController` + views, remove the
courses and consultings controllers/views, and adapt every other affected admin
fragment. Also fix shared model/lib/mailer code that still references the
removed `event.course` association, plus the frontend leftovers that the
previous migration missed.

## Background / current state

- `Course` and `Consulting` model files were deleted in `16b83f5`; only
  `Offer` remains (`type` column, STI disabled). The admin still references the
  dead `Course` / `Consulting` constants — admin is currently broken on this
  branch.
- `Offer` has the union of fields: `title`, `published`, `description`,
  `learning_targets`, `reminder_message`, `email_from` (course-ish) and
  `contact_name`, `contact_email`, `contact_phone` (consulting-ish), plus HABTM
  `topics` / `target_groups` and `has_many :events`.
- `events` table has both `course_id` (NOT NULL) and `offer_id` (nullable, but
  already backfilled by the create_offers migration). `Event belongs_to :offer`.
- Frontend (`Frontend::OffersController` + views) is the reference pattern:
  one index with a `scope` filter (`courses` / `consultings`).

## Decisions (confirmed with user)

1. **Navigation/listing**: single "Angebote" list with a type/scope filter
   (mirrors frontend). One menu entry.
2. **Create flow**: unified offer form with a type picker; fields shown
   conditionally by type.
3. **Events**: nested under all offers (`admin/offers/:offer_id/events`),
   shown for every offer type (the model already permits it).
4. **DB cleanup**: migration drops `events.course_id` + FK, makes
   `events.offer_id` NOT NULL, and drops the `courses` / `consultings` tables
   and their HABTM join tables.
5. **Frontend leftovers**: also fix frontend mailers + frontend events
   controller that still call the removed `event.course`.
6. **Type field**: locked after create — pick type on `new` (radio + live JS
   toggle of the relevant field section); on `edit` the type is shown as a
   read-only label and only that type's section renders.

## Routes (`config/routes.rb`)

Replace the `resources :courses ... do ... end` block and the standalone
`resources :consultings` with a single offers block:

```ruby
resources :offers, except: [:show] do
  get :preview_reminder_message, path: "preview-reminder-message", on: :member

  resources :events, except: [:show], module: :offers do
    get :duplicate, on: :member
    get :preview_reminder_message, path: "preview-reminder-message", on: :member

    resources :registrations, except: [:show], module: :events do
      get :download_certificate, on: :member, path: "certificate/download"
      patch :send_certificate, on: :member, path: "certificate/send"
      patch :send_reminder_message, on: :member, path: "reminder/send"
      patch :bulk_process, path: "bulk-process", on: :collection
      post :send_message, path: "message/send", on: :collection
    end

    resource :report, except: [:destroy], module: :events
    resource :certification, except: [:destroy], module: :events
  end
end
```

The standalone `resources :events, only: [:index] do get :reports ... end` stays.

## Controllers

Namespace rename `Admin::Courses::*` → `Admin::Offers::*`; `Admin::Consultings`
removed (merged into offers).

- **`Admin::OffersController`** (replaces courses + consultings controllers):
  - `index`: `Offer.order("title")` + `Filterable` filter `:offers` with
    `published` (boolean), `title` (string), and `scope`/`type` (string:
    `courses` → `.courses`, `consultings` → `.consultings`).
  - `new`/`create`/`edit`/`update`/`destroy` operate on `Offer`; redirect to
    `edit_admin_offer_path` / `admin_offers_path`.
  - `preview_reminder_message`: build a transient `Offer` + `Event` +
    `Registration` (same as the old course version) using `Offer`.
  - `offer_params`: permit the union — `:type` (only meaningful on create),
    `:title`, `:description`, `:learning_targets`, `:reminder_message`,
    `:email_from`, `:published`, `:contact_name`, `:contact_email`,
    `:contact_phone`, `topic_ids: []`, `target_group_ids: []`. `before_action
    :prepare_offer_context`.
- **`Admin::Offers::EventsController`** (from `Admin::Courses::EventsController`):
  `@course` → `@offer`, `@course.events` → `@offer.events`, path helpers
  `admin_course_event*` → `admin_offer_event*`, destroy redirect to
  `admin_offer_events_path(@offer)`.
- **`Admin::Offers::Events::{Reports,Certifications,Registrations}Controller`**:
  `@course` → `@offer`, path helpers updated, `includes(event: [:course, ...])`
  → `includes(event: [:offer, ...])`, `@course.title` → `@offer.title`. The
  bulk/message turbo_stream partial locals `course: @course` → `offer: @offer`.
- **`Admin::EventsController`** (top-level index): filter `joins(:course)` /
  `"courses.title"` → `joins(:offer)` / `"offers.title"`;
  `Event.includes(:course, :report)` → `includes(:offer, :report)`; render
  `"admin/courses/events/reports/show"` → `"admin/offers/events/reports/show"`.
- **`Admin::ContextHelpers`**: replace `prepare_course_context` /
  `prepare_course_event*` with `prepare_offer_context` /
  `prepare_offer_event*` using `@offer` and `admin_offer_*` paths, breadcrumb
  root label "Angebote". Remove `prepare_consulting_context`.

## Views

Move `app/views/admin/courses/**` → `app/views/admin/offers/**`, renaming
`course` locals → `offer` and `admin_course_*` paths → `admin_offer_*`. Delete
`app/views/admin/consultings/**` (folded into offers). Specifics:

- `offers/index.html.slim`: title "Angebote", "Neues Angebot anlegen" button,
  renders `listing` + `filters`.
- `offers/_listing.html.slim`: rows show published flag, title, a type badge
  (Kurs/Beratung), the events count, and a Termine link for all offers.
- `offers/_filters.html.slim`: published select + title + type/scope select
  (Alle / Kurse / Beratungen), matching the frontend filter shape.
- `offers/_form_fields.html.slim`: unified. Renders a `type` control —
  on `new`, radio buttons (Kurs/Beratung) wired to a Stimulus `offer-form`
  controller; on `edit`, a read-only label (type locked). Common fields
  (published, title, topics, target_groups, description). A course section
  (learning_targets, reminder_message tab + preview, email_from) and a
  consulting section (contact_name/email/phone), each tagged as Stimulus
  targets so the controller shows only the selected type's section. On `edit`,
  only the persisted type's section renders. Reminder preview frame uses
  `preview_reminder_message_admin_offer_path(offer)`.
- `offers/new.html.slim` / `edit.html.slim`: `@course` → `@offer`, titles
  "Neues Angebot …", Termine button on edit → `admin_offer_events_path(@offer)`.
- `offers/events/**` (index, new, edit, _form_fields, _listing, registrations/*,
  reports/*, certifications/*): `course` → `offer` locals and `admin_course_*`
  → `admin_offer_*` path helpers throughout; xlsx filename `@course.title` →
  `@offer.title`.
- `admin/events/_listing.html.slim`: `event.course` → `event.offer`,
  `admin_course_events_path(event.course)` → `admin_offer_events_path(event.offer)`,
  and the per-event action links `admin_course_event*` → `admin_offer_event*`.
- `admin/application/_main_menu.html.slim`: replace the separate "Kurse" and
  "Beratungen" entries with a single "Angebote" entry under a combined section
  linking to `admin_offers_path`.

## Stimulus controller

New `app/assets/src/application/js/stimulus/offer_form_controller.js`
(registered as `offer-form` in `stimulus/application.js`): listens for changes
on the type radios and toggles visibility of the `course`/`consulting` field
sections (targets). Only needed on `new`; harmless on `edit` where the type
control is a static label and a single section renders.

## Shared model / lib / mailer fixes

The `event.course` association no longer exists. Update:

- `Event#effective_reminder_message` / `#effective_email_from`: `course.` →
  `offer.`.
- `Topic` / `TargetGroup`: replace `has_and_belongs_to_many :courses,
  :consultings` with `has_and_belongs_to_many :offers`.
- `app/mailers/admin/mailers/registrations_mailer.rb`,
  `app/mailers/admin/mailers/events_mailer.rb`: `@course = @event.course` →
  `@offer = @event.offer`; update the corresponding mailer views
  (`@course.title` → `@offer.title`).
- `app/mailers/frontend/mailers/registrations_mailer.rb`: `@course =
  registration.event.course` → `@offer = registration.event.offer`; update
  frontend mailer views referencing `@course`.
- `app/controllers/frontend/events_controller.rb`: filter `joins(:course)` /
  `"courses.title"` and `joins(course: :target_groups|:topics)` →
  `joins(:offer)` / `"offers.title"` / `joins(offer: ...)`.
- `app/models/certificate.rb`: `registration.event.course.title` →
  `registration.event.offer.title`; `includes(event: [:course, :certification])`
  call sites → `:offer`.
- `app/helpers/mailer_helper.rb`: `registration.event.course.title` →
  `registration.event.offer.title`.

## Migration

`db/migrate/<ts>_drop_courses_and_consultings.rb`:

```ruby
# events: offer_id is backfilled; drop the legacy course_id, require offer_id
remove_foreign_key :events, :courses
remove_reference   :events, :course
change_column_null :events, :offer_id, false

# drop legacy join tables then base tables
drop_table :courses_topics
drop_table :courses_target_groups
drop_table :consultings_topics
drop_table :consultings_target_groups
drop_table :courses
drop_table :consultings
```

`down` raises `IrreversibleMigration` (consistent with the create_offers
migration). Run `bin/rails db:migrate` to update `schema.rb`.

## Out of scope

- No data backfill beyond what the create_offers migration already did.
- No changes to the public offer URLs or frontend offer views (already done).

## Verification

- `bin/rails routes | grep -E "admin_offer"` shows the new nested routes; no
  `admin_course` / `admin_consulting` routes remain.
- App boots; `grep -rn "event.course\|admin_course\|Course\.\|Consulting\."
  app/` returns nothing (outside comments).
- Manual: create a course-type and consulting-type offer, edit each, add an
  event to an offer, view the events index + reports xlsx.
