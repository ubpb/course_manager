# Admin Offers Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the admin `Course`/`Consulting` controllers and views with a unified `Offer` admin area, fix all shared code that still references the removed `event.course` association, and drop the legacy DB tables.

**Architecture:** Mirror the existing frontend offers migration. One `Admin::OffersController` with a type/scope filter and a unified form (type locked after create). Events and their nested registrations/reports/certifications move from the `Admin::Courses::*` namespace to `Admin::Offers::*`. A DB migration drops `events.course_id` and the `courses`/`consultings` tables.

**Tech Stack:** Rails 8.1, MySQL, Slim views, simple_form, Stimulus, Turbo, axlsx (xlsx exports).

**No automated test suite exists** (`test/` is empty). Verification is via `bin/rails runner` smoke checks, `bin/rails routes`, `grep`, and booting the app. Do NOT run rubocop (user handles linting).

**Path-helper rename rule used throughout:** every `admin_course*` route helper becomes `admin_offer*` (e.g. `admin_courses_path`→`admin_offers_path`, `edit_admin_course_path`→`edit_admin_offer_path`, `admin_course_event_registrations_path`→`admin_offer_event_registrations_path`, `preview_reminder_message_admin_course_path`→`preview_reminder_message_admin_offer_path`). A single substring replace `admin_course`→`admin_offer` covers all variants.

---

## File Structure

**Migration**
- Create: `db/migrate/<ts>_drop_courses_and_consultings.rb`

**Models**
- Modify: `app/models/event.rb`, `app/models/topic.rb`, `app/models/target_group.rb`, `app/models/certificate.rb`

**Shared lib / helpers / mailers**
- Modify: `app/helpers/mailer_helper.rb`
- Modify: `app/mailers/admin/mailers/events_mailer.rb`, `app/mailers/admin/mailers/registrations_mailer.rb`, `app/mailers/frontend/mailers/registrations_mailer.rb`
- Modify mailer views: `app/views/admin/mailers/**`, `app/views/frontend/mailers/**` that use `@course`
- Modify: `app/controllers/frontend/events_controller.rb`, `app/views/frontend/application/_categorisation_badges.html.slim`

**Routes**
- Modify: `config/routes.rb`

**Controllers**
- Create: `app/controllers/admin/offers_controller.rb`
- Move+edit: `app/controllers/admin/courses/` tree → `app/controllers/admin/offers/`
- Modify: `app/controllers/concerns/admin/context_helpers.rb`, `app/controllers/admin/events_controller.rb`
- Delete: `app/controllers/admin/courses_controller.rb`, `app/controllers/admin/consultings_controller.rb`

**Views**
- Move+edit: `app/views/admin/courses/` → `app/views/admin/offers/`
- Delete: `app/views/admin/consultings/`
- Modify: `app/views/admin/events/_listing.html.slim`, `app/views/admin/application/_main_menu.html.slim`
- Rewrite: `app/views/admin/offers/_form_fields.html.slim` (unified), `app/views/admin/offers/_filters.html.slim`, `app/views/admin/offers/index.html.slim`, `app/views/admin/offers/_listing.html.slim`

**JS**
- Create: `app/assets/src/application/js/stimulus/offer_form_controller.js`
- Modify: `app/assets/src/application/js/stimulus/application.js`

**i18n**
- Modify: `config/locales/de/simple_form.yml`

---

## Task 1: DB migration — drop legacy tables and `course_id`

**Files:**
- Create: `db/migrate/<ts>_drop_courses_and_consultings.rb`
- Modify (generated): `db/schema.rb`

- [ ] **Step 1: Confirm every event already has an offer_id (must be empty)**

Run:
```bash
bin/rails runner 'puts Event.where(offer_id: nil).count'
```
Expected: `0` (the create_offers migration backfilled offer_id). If non-zero, STOP — do not proceed; the data needs fixing first.

- [ ] **Step 2: Generate the migration file**

Run:
```bash
bin/rails generate migration DropCoursesAndConsultings
```

- [ ] **Step 3: Write the migration**

Replace the generated file body with:
```ruby
class DropCoursesAndConsultings < ActiveRecord::Migration[8.1]

  def up
    # events.offer_id is backfilled; drop the legacy course_id and require offer_id.
    remove_reference :events, :course, foreign_key: true
    change_column_null :events, :offer_id, false

    # Drop legacy HABTM join tables, then the base tables.
    drop_table :courses_topics
    drop_table :courses_target_groups
    drop_table :consultings_topics
    drop_table :consultings_target_groups
    drop_table :courses
    drop_table :consultings
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
      "Die ursprünglichen Course- und Consulting-Tabellen können nicht wiederhergestellt werden."
  end

end
```

- [ ] **Step 4: Run the migration**

Run:
```bash
bin/rails db:migrate
```
Expected: migration runs without error; `db/schema.rb` updated.

- [ ] **Step 5: Verify schema**

Run:
```bash
grep -nE '"courses"|"consultings"|course_id' db/schema.rb
bin/rails runner 'puts Event.column_names.include?("course_id") ? "HAS course_id" : "ok"'
```
Expected: grep prints nothing; runner prints `ok`.

- [ ] **Step 6: Commit**

```bash
git add db/migrate db/schema.rb
git commit -m "Drop legacy courses/consultings tables and events.course_id

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Fix model associations referencing removed `course`

**Files:**
- Modify: `app/models/event.rb:53-59`
- Modify: `app/models/topic.rb:4-5`
- Modify: `app/models/target_group.rb:4-5`

- [ ] **Step 1: Fix `Event` effective_* methods**

In `app/models/event.rb`, change:
```ruby
  def effective_reminder_message
    reminder_message.presence || course.reminder_message.presence
  end

  def effective_email_from
    email_from.presence || course.email_from.presence
  end
```
to:
```ruby
  def effective_reminder_message
    reminder_message.presence || offer.reminder_message.presence
  end

  def effective_email_from
    email_from.presence || offer.email_from.presence
  end
```

- [ ] **Step 2: Fix `Topic` associations**

In `app/models/topic.rb`, replace:
```ruby
  has_and_belongs_to_many :courses # rubocop:disable Rails/HasAndBelongsToMany
  has_and_belongs_to_many :consultings # rubocop:disable Rails/HasAndBelongsToMany
```
with:
```ruby
  has_and_belongs_to_many :offers # rubocop:disable Rails/HasAndBelongsToMany
```

- [ ] **Step 3: Fix `TargetGroup` associations**

In `app/models/target_group.rb`, apply the same replacement as Step 2.

- [ ] **Step 4: Verify**

Run:
```bash
bin/rails runner 'o=Offer.first; puts o ? [o.topics.size, o.target_groups.size, Event.new.respond_to?(:offer)].inspect : "no offers in db"'
```
Expected: prints an array like `[n, n, true]` (or "no offers in db" on an empty DB — acceptable, the point is no NameError).

- [ ] **Step 5: Commit**

```bash
git add app/models/event.rb app/models/topic.rb app/models/target_group.rb
git commit -m "Point Event/Topic/TargetGroup at offers instead of courses

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Fix mailers, certificate, helper, and frontend leftovers

**Files:**
- Modify: `app/mailers/admin/mailers/events_mailer.rb:11,27`
- Modify: `app/mailers/admin/mailers/registrations_mailer.rb:8,25`
- Modify: `app/mailers/frontend/mailers/registrations_mailer.rb:29`
- Modify: `app/models/certificate.rb:29`
- Modify: `app/helpers/mailer_helper.rb:44`
- Modify: `app/controllers/frontend/events_controller.rb:10,26,30`
- Modify: `app/views/admin/mailers/registrations_mailer/user_message.text.erb:3`, `app/views/admin/mailers/registrations_mailer/certificate.text.erb:3`, `app/views/admin/mailers/events_mailer/changed_notification.text.erb:3`
- Modify: `app/views/frontend/mailers/registrations_mailer/notification.text.erb:5`, `app/views/frontend/mailers/registrations_mailer/confirmation.text.erb:3`
- Modify: `app/views/frontend/application/_categorisation_badges.html.slim:3`

- [ ] **Step 1: Rename `@course`/`event.course` in mailers**

In each mailer, change the ivar assignment from the course association to the offer association, renaming the ivar to `@offer`:
- `app/mailers/admin/mailers/events_mailer.rb`: both `@course = @event.course` → `@offer = @event.offer`
- `app/mailers/admin/mailers/registrations_mailer.rb`: both `@course = @event.course` → `@offer = @event.offer`
- `app/mailers/frontend/mailers/registrations_mailer.rb`: `@course = registration.event.course` → `@offer = registration.event.offer`

- [ ] **Step 2: Update mailer views to use `@offer`**

In each of these `.erb` views, replace `@course.title` with `@offer.title`:
- `app/views/admin/mailers/registrations_mailer/user_message.text.erb`
- `app/views/admin/mailers/registrations_mailer/certificate.text.erb`
- `app/views/admin/mailers/events_mailer/changed_notification.text.erb`
- `app/views/frontend/mailers/registrations_mailer/notification.text.erb`
- `app/views/frontend/mailers/registrations_mailer/confirmation.text.erb`

Run to confirm none remain:
```bash
grep -rn "@course" app/views/admin/mailers app/views/frontend/mailers app/mailers
```
Expected: nothing.

- [ ] **Step 3: Fix `Certificate` and `MailerHelper`**

- `app/models/certificate.rb:29`: `registration.event.course.title` → `registration.event.offer.title`
- `app/helpers/mailer_helper.rb:44`: `registration.event.course.title` → `registration.event.offer.title`

- [ ] **Step 4: Fix frontend events controller filters**

In `app/controllers/frontend/events_controller.rb`, change:
```ruby
        arel.joins(:course).where("courses.title like ?", "%#{ApplicationRecord.sanitize_sql_like(title)}%")
```
→
```ruby
        arel.joins(:offer).where("offers.title like ?", "%#{ApplicationRecord.sanitize_sql_like(title)}%")
```
and:
```ruby
        arel.joins(course: :target_groups).where("target_groups.id IN (?)", target_group_ids)
```
→
```ruby
        arel.joins(offer: :target_groups).where("target_groups.id IN (?)", target_group_ids)
```
and:
```ruby
        arel.joins(course: :topics).where("topics.id IN (?)", topic_ids)
```
→
```ruby
        arel.joins(offer: :topics).where("topics.id IN (?)", topic_ids)
```

- [ ] **Step 5: Simplify categorisation badges partial**

In `app/views/frontend/application/_categorisation_badges.html.slim`, replace line 3:
```slim
- offer_type = object.respond_to?(:type) ? object.type : (object.is_a?(Course) ? "course" : "consulting")
```
with:
```slim
- offer_type = object.type
```
(`Course`/`Consulting` constants no longer exist; all callers pass an `Offer`.)

- [ ] **Step 6: Verify no stray course references remain in these files**

Run:
```bash
grep -rnE "event\.course|events\.course|\.event\.course|is_a\?\(Course|joins\(:course|joins\(course:|courses\.title" app/mailers app/models/certificate.rb app/helpers/mailer_helper.rb app/controllers/frontend/events_controller.rb app/views/frontend/application/_categorisation_badges.html.slim
```
Expected: nothing.

- [ ] **Step 7: Commit**

```bash
git add app/mailers app/models/certificate.rb app/helpers/mailer_helper.rb app/controllers/frontend app/views/admin/mailers app/views/frontend/mailers app/views/frontend/application/_categorisation_badges.html.slim
git commit -m "Replace removed event.course association with event.offer in shared code

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Routes — replace courses/consultings with offers

**Files:**
- Modify: `config/routes.rb` (admin namespace)

- [ ] **Step 1: Replace the courses block and consultings resource**

In the `namespace :admin do` block, delete the entire `resources :courses, except: [:show] do ... end` block AND the standalone `resources :consultings, except: [:show]` line, and insert in their place:
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
Leave the standalone `resources :events, only: [:index] do ... end`, `target_groups`, and `topics` blocks unchanged.

- [ ] **Step 2: Verify routes (controllers not built yet, so just check helper names exist)**

Run:
```bash
bin/rails routes -g offer 2>/dev/null | grep -E "admin_offer" | head
bin/rails routes 2>/dev/null | grep -E "admin_course|admin_consulting" || echo "no legacy admin routes"
```
Expected: first command lists `admin_offers`, `admin_offer_events`, etc.; second prints `no legacy admin routes`. (Routes evaluate even before controllers exist.)

- [ ] **Step 3: Commit**

```bash
git add config/routes.rb
git commit -m "Replace admin courses/consultings routes with offers

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: `Admin::OffersController` + `ContextHelpers` + top-level `EventsController`

**Files:**
- Create: `app/controllers/admin/offers_controller.rb`
- Delete: `app/controllers/admin/courses_controller.rb`, `app/controllers/admin/consultings_controller.rb`
- Modify: `app/controllers/concerns/admin/context_helpers.rb`
- Modify: `app/controllers/admin/events_controller.rb:43,77,85`

- [ ] **Step 1: Create the unified offers controller**

Create `app/controllers/admin/offers_controller.rb`:
```ruby
module Admin
  class OffersController < ApplicationController

    include Filterable

    before_action :prepare_offer_context

    define_filter :offers do
      filter_by :published, :boolean, default: nil do |arel, published|
        arel.where(published: published)
      end

      filter_by :scope, :string do |arel, scope|
        case scope
        when "courses"
          arel.courses
        when "consultings"
          arel.consultings
        else
          arel
        end
      end

      filter_by :title, :string do |arel, title|
        arel.where("title like ?", "%#{ApplicationRecord.sanitize_sql_like(title)}%")
      end
    end

    def index
      @offers = Offer.order("title")

      @filter = create_filter(:offers) or return
      @offers = @filter.filter(@offers)
    end

    def new
      @offer = Offer.new(type: "course")
    end

    def create
      @offer = Offer.new(offer_params)

      if @offer.save
        redirect_to edit_admin_offer_path(@offer), notice: t("admin.application.form.success")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @offer.update(offer_params)
        redirect_to edit_admin_offer_path(@offer), notice: t("admin.application.form.success")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @offer.destroy
      redirect_to admin_offers_path, notice: t("admin.application.form.destroy_success")
    end

    def preview_reminder_message
      offer = Offer.find(params[:id])

      event = Event.new(
        offer: offer,
        date_and_time: Time.zone.now,
        duration: 60,
        location: "Raum 123"
      )

      registration = Registration.new(
        event: event,
        first_name: "Max",
        last_name: "Mustermann",
        email: "schulung@ub.uni-paderborn.de"
      )

      mail = Admin::Mailers::EventsMailer.reminder_message(registration, skip_if_sent: false)
      @preview = mail.body.to_s
    end

    private

    def offer_params
      params.require(:offer).permit(
        :type, :title, :description, :learning_targets, :reminder_message,
        :email_from, :published, :contact_name, :contact_email, :contact_phone,
        topic_ids: [], target_group_ids: []
      )
    end

  end
end
```

- [ ] **Step 2: Delete the old controllers**

Run:
```bash
git rm app/controllers/admin/courses_controller.rb app/controllers/admin/consultings_controller.rb
```

- [ ] **Step 3: Rewrite `Admin::ContextHelpers`**

Replace the entire body of `app/controllers/concerns/admin/context_helpers.rb` with:
```ruby
module Admin
  module ContextHelpers

    extend ActiveSupport::Concern

    private

    def prepare_offer_context
      add_breadcrumb "Angebote", admin_offers_path

      offer_id = params[:offer_id] || params[:id] || return
      @offer = Offer.includes(:events).find(offer_id)

      add_breadcrumb @offer.title, edit_admin_offer_path(@offer)
    end

    def prepare_offer_event_context
      prepare_offer_context

      add_breadcrumb "Termine", admin_offer_events_path(@offer)

      event_id = params[:event_id] || params[:id] || return
      @event = @offer.events.includes(:report, :registrations).find(event_id)

      add_breadcrumb I18n.l(@event.date_and_time), edit_admin_offer_event_path(@offer, @event)
    end

    def prepare_offer_event_registration_context
      prepare_offer_event_context

      add_breadcrumb "Anmeldungen", admin_offer_event_registrations_path(@offer, @event)

      registration_id = params[:registration_id] || params[:id] || return
      @registration = @event.registrations.find(registration_id)

      add_breadcrumb @registration.full_name_reversed, edit_admin_offer_event_path(@offer, @event)
    end

    def prepare_offer_event_report_context
      prepare_offer_event_context

      @report = @event.report
      add_breadcrumb "Statistik", admin_offer_event_report_path(@offer, @event)
    end

    def prepare_offer_event_certification_context
      prepare_offer_event_context

      @certification = @event.certification
      add_breadcrumb "Zertifizierung", admin_offer_event_report_path(@offer, @event)
    end

  end
end
```

- [ ] **Step 4: Update the top-level `Admin::EventsController`**

In `app/controllers/admin/events_controller.rb`:
- Line 43, change the title filter:
  ```ruby
        arel.joins(:course).where("courses.title like ?", "%#{ApplicationRecord.sanitize_sql_like(title)}%")
  ```
  →
  ```ruby
        arel.joins(:offer).where("offers.title like ?", "%#{ApplicationRecord.sanitize_sql_like(title)}%")
  ```
- Line 77, change the render path:
  ```ruby
          render "admin/courses/events/reports/show"
  ```
  →
  ```ruby
          render "admin/offers/events/reports/show"
  ```
- Line 85, change the includes:
  ```ruby
      @events = Event.includes(:course, :report).order(date_and_time: :desc)
  ```
  →
  ```ruby
      @events = Event.includes(:offer, :report).order(date_and_time: :desc)
  ```

- [ ] **Step 5: Verify (controller classes load)**

Run:
```bash
bin/rails runner 'puts [Admin::OffersController, Admin::EventsController].map(&:name).inspect'
```
Expected: `["Admin::OffersController", "Admin::EventsController"]` with no NameError.

- [ ] **Step 6: Commit**

```bash
git add app/controllers/admin/offers_controller.rb app/controllers/concerns/admin/context_helpers.rb app/controllers/admin/events_controller.rb
git commit -m "Add Admin::OffersController; migrate context helpers and events controller to offers

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Move events sub-controllers into `Admin::Offers` namespace

**Files:**
- Move: `app/controllers/admin/courses/events_controller.rb` → `app/controllers/admin/offers/events_controller.rb`
- Move: `app/controllers/admin/courses/events/{reports,certifications,registrations}_controller.rb` → `app/controllers/admin/offers/events/`

- [ ] **Step 1: Move the controller directory**

Run:
```bash
git mv app/controllers/admin/courses app/controllers/admin/offers
```

- [ ] **Step 2: Apply mechanical renames across the moved tree**

Run (BSD sed on macOS — `-i ''`):
```bash
find app/controllers/admin/offers -name '*.rb' -print0 | xargs -0 sed -i '' \
  -e 's/module Courses/module Offers/g' \
  -e 's/admin_course/admin_offer/g' \
  -e 's/@course/@offer/g' \
  -e 's/prepare_course_event/prepare_offer_event/g' \
  -e 's/event: \[:course/event: [:offer/g' \
  -e 's/includes(:course/includes(:offer/g'
```

- [ ] **Step 3: Fix remaining `@offer.title` / lingering bare `course` references**

Run to find anything left:
```bash
grep -rnE "course" app/controllers/admin/offers
```
Expected matches are only the intended ones already renamed. Manually verify NONE of these remain (fix by hand if so):
- `module Courses` (should be `module Offers`)
- `prepare_course_*`, `admin_course_*`, `@course`, `Course.`, `:course` in `includes`/`joins`

After fixing, re-run the grep; expected: nothing prints.

- [ ] **Step 4: Verify the controllers load**

Run:
```bash
bin/rails runner 'puts [Admin::Offers::EventsController, Admin::Offers::Events::ReportsController, Admin::Offers::Events::CertificationsController, Admin::Offers::Events::RegistrationsController].map(&:name).inspect'
```
Expected: the four class names, no NameError.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/admin/offers
git commit -m "Move admin events sub-controllers into Offers namespace

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: Stimulus `offer-form` controller (type section toggle)

**Files:**
- Create: `app/assets/src/application/js/stimulus/offer_form_controller.js`
- Modify: `app/assets/src/application/js/stimulus/application.js`

- [ ] **Step 1: Create the controller**

Create `app/assets/src/application/js/stimulus/offer_form_controller.js`:
```javascript
import { Controller } from "@hotwired/stimulus"

// Toggles the course-specific and consulting-specific field sections of the
// offer form based on the selected `type` radio. Used only on the "new" form;
// on "edit" the type is locked and only the matching section is rendered, so
// there are no type radios and connect() leaves the server-rendered state.
export default class extends Controller {
  static targets = ["type", "course", "consulting"]

  connect() {
    this.toggle()
  }

  toggle() {
    const selected = this.selectedType()
    if (!selected) return

    this.courseTargets.forEach(el => el.hidden = selected !== "course")
    this.consultingTargets.forEach(el => el.hidden = selected !== "consulting")
  }

  selectedType() {
    const checked = this.typeTargets.find(input => input.checked)
    return checked ? checked.value : null
  }
}
```

- [ ] **Step 2: Register the controller**

In `app/assets/src/application/js/stimulus/application.js`, after the existing `FilterForm` registration, add:
```javascript
import OfferForm from "./offer_form_controller.js"
application.register("offer-form", OfferForm)
```

- [ ] **Step 3: Verify file present and imports match**

Run:
```bash
grep -n "offer-form\|OfferForm" app/assets/src/application/js/stimulus/application.js
```
Expected: the import line and the register line.

- [ ] **Step 4: Commit**

```bash
git add app/assets/src/application/js/stimulus/offer_form_controller.js app/assets/src/application/js/stimulus/application.js
git commit -m "Add offer-form Stimulus controller to toggle type sections

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: Move admin views into `offers/` and apply mechanical renames

**Files:**
- Move: `app/views/admin/courses` → `app/views/admin/offers`
- Delete: `app/views/admin/consultings`

- [ ] **Step 1: Move the views directory and remove consultings views**

Run:
```bash
git mv app/views/admin/courses app/views/admin/offers
git rm -r app/views/admin/consultings
```

- [ ] **Step 2: Apply mechanical renames across the moved tree**

Run (covers `.slim` and `.axlsx` views):
```bash
find app/views/admin/offers -type f -print0 | xargs -0 sed -i '' \
  -e 's/admin_course/admin_offer/g' \
  -e 's/@course/@offer/g' \
  -e 's/\.event\.course/.event.offer/g' \
  -e 's/event\.course/event.offer/g' \
  -e 's/\bcourse\b/offer/g'
```
Note: the last rule maps the standalone local `course` (and `course:` locals, `course.title`, `course?`) to `offer`. The earlier rules run first so `admin_course*` and `event.course` are already handled.

- [ ] **Step 3: Verify no stray `course` tokens remain in the moved tree**

Run:
```bash
grep -rniE "course|@course" app/views/admin/offers
```
Expected: nothing. If any remain, fix by hand (e.g. a comment locals line `(form:, course:)` should now read `(form:, offer:)`).

- [ ] **Step 4: Commit**

```bash
git add app/views/admin/offers
git rm -r --cached app/views/admin/consultings 2>/dev/null || true
git commit -m "Move admin course views to offers and rename references

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: Rewrite the offers index, listing, filters, and form

These four files need more than a mechanical rename (unified type handling, new labels). Replace them fully.

**Files:**
- Modify: `app/views/admin/offers/index.html.slim`
- Modify: `app/views/admin/offers/_listing.html.slim`
- Modify: `app/views/admin/offers/_filters.html.slim`
- Modify: `app/views/admin/offers/_form_fields.html.slim`

- [ ] **Step 1: Rewrite `index.html.slim`**

```slim
.row
  .col-md-9
    .card.card-shadowed
      .card-header.d-flex.align-items-center.gap-2
        h5.card-title.mb-0 = "Angebote"
        .ms-auto
        = link_to new_admin_offer_path, class: "btn btn-primary btn-sm" do
          i.fa-solid.fa-plus.me-2
          = "Neues Angebot anlegen"
      .card-body
        - if @offers.present?
          = render "listing", offers: @offers
        - else
          .p-2.text-muted = "Keine Angebote vorhanden"

  .col-md-3
    = render "filters"
```

- [ ] **Step 2: Rewrite `_listing.html.slim`**

```slim
/ <%# locals: (offers:) -%>

table.table
  thead
    tr
      th(colspan="2") = "Name"
      th = "Art"
      th = "Termine"
      th.actions = "Aktionen"
  tbody
    - offers.each do |offer|
      tr(id=dom_id(offer))
        td(width="1" class="#{offer.published? ? "table-success" : "table-danger"}") = ""
        td = offer.title
        td = offer.course? ? "Kurs" : "Beratung"
        td = "#{offer.events.upcoming.count} / #{offer.events.past.count}"
        td.actions
          .dropdown
            button.btn.btn-outline-primary.btn-sm.dropdown-toggle(type="button" data-bs-toggle="dropdown")
              i.fas.fa-cog
            ul.dropdown-menu.dropdown-menu-end
              li = link_to edit_admin_offer_path(offer), class: "dropdown-item" do
                i.fa-solid.fa-edit.me-2
                = "Bearbeiten"
              hr.dropdown-divider
              li = link_to admin_offer_events_path(offer), class: "dropdown-item" do
                i.fa-solid.fa-calendar-alt.me-2
                = "Termine"
```

- [ ] **Step 3: Rewrite `_filters.html.slim`**

```slim
= simple_form_for :filter, url: admin_offers_path, method: :get, html: { data: { controller: "filter-form" } } do |form|
  .card
    .card-header
      h5.card-title.mb-0 Filter
    .card-body
      = form.input :scope, as: :select, collection: [["Kurse", "courses"], ["Beratungen", "consultings"]], include_blank: "Alle", required: false
      = form.input :published, as: :select, collection: [["Ja", "true"], ["Nein", "false"]], include_blank: true, required: false
      = form.input :title, required: false
    .card-footer
      .d-grid.gap-2
        = form.submit t("admin.application.btn_filter"), class: "btn btn-primary"
        - if @filter&.active?
          = form.submit t("admin.application.btn_filter_reset"), name: "reset_filter", class: "btn btn-link"
```

- [ ] **Step 4: Rewrite `_form_fields.html.slim` (unified, type locked after create)**

```slim
/ <%# locals: (form:, offer:) -%>

- if form.object.errors.any?
  .alert.alert-danger.mb-3.text-center
    i.fa-solid.fa-exclamation-triangle.me-2
    = t("admin.application.form.error", count: form.object.errors.count)

div data-controller="offer-form"
  h5.m-0 Allgemeine Angaben
  hr.mt-1.mb-3

  - if offer.persisted?
    .mb-3
      label.form-label.d-block = "Art"
      = offer.course? ? "Kurs" : "Beratung"
  - else
    = form.input :type, as: :radio_buttons, collection: [["Kurs", "course"], ["Beratung", "consulting"]], label: "Art", item_wrapper_class: "form-check-inline", input_html: { data: { action: "change->offer-form#toggle", "offer-form-target": "type" } }

  = form.input :published, as: :boolean
  = form.input :title
  .row
    .col
      = form.association :topics, as: :check_boxes
    .col
      = form.association :target_groups, as: :check_boxes
  = form.input :description, as: :text, input_html: { rows: 8 }

  / Kurs-spezifisch
  div data-offer-form-target="course" hidden=(offer.persisted? && offer.consulting?)
    = form.input :learning_targets, as: :text, input_html: { rows: 8 }

    h5.mt-4.mb-0 Administrative Angaben
    hr.mt-1.mb-3
    ul.nav.nav-tabs.mb-3
      li.nav-item
        button#reminder-message-tab.nav-link.active(data-bs-toggle="tab" data-bs-target="#reminder-message-pane" type="button") = "E-Mail Erinnerung"
      li.nav-item
        button#reminder-message-preview-tab.nav-link(data-bs-toggle="tab" data-bs-target="#reminder-message-preview-pane" type="button") = "Vorschau"

    .tab-content
      #reminder-message-pane.tab-pane.fade.show.active
        = form.input :reminder_message, as: :text, input_html: { rows: 8 }, label: false
        = form.input :email_from
      #reminder-message-preview-pane.tab-pane.fade.show
        - if offer.persisted?
          = turbo_frame_tag "reminder-message-preview", src: preview_reminder_message_admin_offer_path(offer)
        - else
          = "Bitte speichern Sie das Angebot, um eine Vorschau der E-Mail zu sehen."

  / Beratung-spezifisch
  div data-offer-form-target="consulting" hidden=(!offer.persisted? || offer.course?)
    = form.input :contact_name
    .row
      .col = form.input :contact_email
      .col = form.input :contact_phone

  / javascript:
    const previewTab = document.querySelector("#reminder-message-preview-tab")
    if (previewTab) {
      previewTab.addEventListener("show.bs.tab", event => {
        const previewFrame = document.querySelector("#reminder-message-preview")
        previewFrame.reload()
      })
    }
```
Notes: on `new` both section divs render un-hidden in markup and the Stimulus `offer-form` controller hides the non-selected one on connect (default type is `course`). On `edit` the type is locked, so the wrong section is `hidden` via server-rendered attribute and the controller's `connect()` no-ops (no type radios).

- [ ] **Step 5: Fix the `new`/`edit` wrappers to pass the `offer` local and update labels**

The mechanical sed already renamed `@course`→`@offer` and `course:`→`offer:` in `app/views/admin/offers/new.html.slim` and `edit.html.slim`. Confirm they now read `render "form_fields", form: form, offer: @offer` and update the German headings:
- `new.html.slim`: heading `"Neuen Kurs anlegen"` → `"Neues Angebot anlegen"`
- `edit.html.slim`: heading `"Kurs bearbeiten"` → `"Angebot bearbeiten"`; the Termine button stays (`admin_offer_events_path(@offer)`).

Run to confirm the render locals are correct:
```bash
grep -n "render \"form_fields\"" app/views/admin/offers/new.html.slim app/views/admin/offers/edit.html.slim
```
Expected: both pass `form: form, offer: @offer`.

- [ ] **Step 6: Commit**

```bash
git add app/views/admin/offers/index.html.slim app/views/admin/offers/_listing.html.slim app/views/admin/offers/_filters.html.slim app/views/admin/offers/_form_fields.html.slim app/views/admin/offers/new.html.slim app/views/admin/offers/edit.html.slim
git commit -m "Unified admin offers index, listing, filters, and form

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 10: Fix the events index listing and the main menu

**Files:**
- Modify: `app/views/admin/events/_listing.html.slim:19,40,44,47,50`
- Modify: `app/views/admin/application/_main_menu.html.slim:5-19`

- [ ] **Step 1: Fix `admin/events/_listing.html.slim`**

Apply mechanical renames to this single file:
```bash
sed -i '' \
  -e 's/admin_course/admin_offer/g' \
  -e 's/event\.course/event.offer/g' \
  app/views/admin/events/_listing.html.slim
```
Then verify the column/link now reads `link_to event.offer.title, admin_offer_events_path(event.offer)` and the action links use `admin_offer_event_*`:
```bash
grep -nE "course|admin_offer" app/views/admin/events/_listing.html.slim
```
Expected: no `course` tokens; `admin_offer_*` helpers present.

- [ ] **Step 2: Collapse the menu into a single "Angebote" entry**

In `app/views/admin/application/_main_menu.html.slim`, replace the "Schulungen" + "Beratungen" sections (the `h5.text-muted = "Schulungen"` block through the end of the `h5.text-muted = "Beratungen"` block) with:
```slim
  h5.text-muted = "Angebote"
  nav.list-group.mb-4
    = link_to admin_events_path, class: "list-group-item list-group-item-action" do
      i.fa-solid.fa-calendar-days.me-2
      = "Termine"
    = link_to admin_offers_path, class: "list-group-item list-group-item-action" do
      i.fa-solid.fa-box-open.me-2
      = "Angebote"
```
Leave the "Kategorisierung" section and `= render "application/main_menu"` unchanged.

- [ ] **Step 3: Verify**

Run:
```bash
grep -nE "admin_course|admin_consulting" app/views/admin/application/_main_menu.html.slim || echo "menu clean"
```
Expected: `menu clean`.

- [ ] **Step 4: Commit**

```bash
git add app/views/admin/events/_listing.html.slim app/views/admin/application/_main_menu.html.slim
git commit -m "Point admin events listing and main menu at offers

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 11: i18n labels for offer form

**Files:**
- Modify: `config/locales/de/simple_form.yml:51-55`

- [ ] **Step 1: Rename the `consulting` label block to `offer`**

In `config/locales/de/simple_form.yml`, under `de.simple_form.labels`, rename the model key `consulting:` to `offer:` (the contact labels apply to the Offer model now):
```yaml
      offer:
        contact_name: "Kontakt"
        contact_email: "E-Mail"
        contact_phone: "Telefon"
        type: "Art"
```

- [ ] **Step 2: Verify YAML parses**

Run:
```bash
bin/rails runner 'I18n.t("simple_form.labels.offer.contact_name").tap { |v| puts v }'
```
Expected: `Kontakt`.

- [ ] **Step 3: Commit**

```bash
git add config/locales/de/simple_form.yml
git commit -m "Add offer simple_form labels

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 12: Full verification pass

- [ ] **Step 1: Grep for any remaining legacy references in app code**

Run:
```bash
grep -rnE "admin_course|admin_consulting|prepare_course|prepare_consulting|@course\b|@consulting\b|\bCourse\b|\bConsulting\b|event\.course|courses\.title|joins\(:course\)|includes\(:course" app/ config/ \
  | grep -viE "frontend_courses_path|frontend_consultings_path|frontend/(courses|consultings)_controller"
```
Expected: nothing. (The only allowed survivors are the frontend redirect routes `frontend_courses_path`/`frontend_consultings_path` and the frontend redirect controllers, which are intentional and out of scope.)

- [ ] **Step 2: Boot check — eager load all classes**

Run:
```bash
bin/rails runner 'Rails.application.eager_load!; puts "boot ok"'
```
Expected: `boot ok` with no load errors.

- [ ] **Step 3: Routes sanity**

Run:
```bash
bin/rails routes 2>/dev/null | grep -E "admin_offer" | wc -l
bin/rails routes 2>/dev/null | grep -E "admin_course|admin_consulting" || echo "no legacy admin routes"
```
Expected: a positive count of admin_offer routes; `no legacy admin routes`.

- [ ] **Step 4: Manual smoke (use the `run` skill or a dev server)**

Start the app and verify, logged in as admin:
1. `/admin/offers` lists offers with Art column + type filter (Alle/Kurse/Beratungen) works.
2. "Neues Angebot anlegen" → choosing Kurs shows reminder/email fields; choosing Beratung shows contact fields (JS toggle).
3. Create a course-type offer; edit it — Art shows as locked label "Kurs", reminder preview frame loads.
4. Create a consulting-type offer; edit — Art locked "Beratung", contact fields shown.
5. Open an offer's Termine, create an event, open its registrations, and export the registrations xlsx.
6. `/admin/events` index: title filter works, the offer title links to the offer's events, the report xlsx export downloads.

- [ ] **Step 5: Final commit (if any manual fixes were needed)**

```bash
git add -A
git commit -m "Finalize admin offers migration

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review Notes (for the implementer)

- **macOS sed:** all `sed -i` commands use the BSD form `sed -i ''`. On a GNU/Linux box use `sed -i` (no `''`).
- **Order matters** in the bulk sed rules: `admin_course`→`admin_offer` and `event.course`→`event.offer` run before the broad `\bcourse\b`→`offer`.
- **Slim `hidden` attribute:** `hidden=(condition)` renders the boolean `hidden` attribute only when the condition is truthy; verify the toggle behaves (inspect element) during the manual smoke.
- If `bin/rails runner` cannot connect to MySQL in this environment, run the boot/route checks wherever the dev DB is available; the grep checks are environment-independent.
