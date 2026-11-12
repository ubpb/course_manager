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
them, not even with `git add -f`, although the `brainstorming` skill says to commit the spec. Code, comments, docs
and commit messages do not refer to them, since no one else can read them. What lasts is in the code and its tests,
the docs, the commit messages and, for a central decision, an [ADR](#decisions). An open question in design or
planning can be settled with a throwaway prototype; what it teaches goes into the spec, the prototype is not kept.

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
- Docs change with the code, in the same branch: the README, and this file when a rule, convention, command or
  pitfall changes. How a feature behaves belongs in its code and tests, not here.
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
bin/dev                   # start Rails server (thin wrapper around `rails server`; does not build JS)
bun run build:watch       # rebuild JS/CSS on change; run it next to bin/dev in a second terminal
bun run build             # one-off asset build → app/assets/builds/
bin/ci                    # CI: setup, rubocop, gem and JS audit, brakeman, tests, system tests, seeds (config/ci.rb)
bin/rails test            # run minitest suite (without system tests)
bin/rails test:system     # run system tests in headless Chrome (needs built assets)
bin/rubocop               # lint (config: rubocop-ubpb rails.yml, see .rubocop.yml); -a for safe autocorrections
```

- **Database is MySQL/MariaDB** (`mysql2`, socket `/tmp/mysql.sock`; servers run MariaDB 11.8), the only database — no sqlite. Solid Queue's tables live in it too (no separate queue DB). Running `rake`/`bin/rails test` **regenerates the test DB from development** — don't point them at the same DB.

## Assets — non-standard

Propshaft + **Bun as the bundler** (not importmap or jsbundling): `bun.build.js` bundles `app/assets-src/application.js`, SCSS included (`bun.plugin.sass.js`), into `app/assets/builds/`. Views are **Slim**, forms **simple_form** with Bootstrap, JavaScript behaviour **Stimulus** controllers.

## Architecture

What reading one file does not show: rules that span several places, and the reasons behind them.

- `Offer#type` is a plain column (`Offer::TYPES`: `"course"`, `"consulting"`, `"self_study_course"`), not STI: use the `course?`/`consulting?`/`self_study_course?` predicates and the matching plural scopes. **Only courses have events**, enforced in the admin `ContextHelpers` and the frontend `prepare_event_context`; other offers can set `events_on_request` instead.
- An offer's contact and call to action fall back to the defaults in `config/application.yml` (`default_contact`, `default_call_to_action`); a `before_save` nulls a value equal to the current default, so the database holds only real overrides.
- The frontend shows only published offers that are not archived, and their events (`Event.from_published_offers`, `.from_non_archived_offers`); the admin offer list leaves archived offers out unless filtered for. There is deliberately no event show page: events appear on the page of their offer.
- A no-show (`Registration#no_show`) gets no certificate by any path: the account refuses the download, the admin its download and single mail, and the bulk mail leaves no-shows out. Seats, reminders and report figures ignore the mark.
- A registration with an ILS id (`ils_primary_id`) was made by the participant, since registering takes a login; one without it was entered in the admin (`entered_in_admin?`). Anonymizing drops the ILS id as well, so an anonymized registration counts as neither.
- Email fields accept only `@ub.uni-paderborn.de` addresses or blank (`ApplicationRecord::UPB_EMAIL_REGEXP`), test records included.
- The admin keeps its login in a signed cookie of its own (`:admin_user`, path `/admin`), not in the session, because the frontend shares the session and rotates it on its own login.
- An environment variable named after the upcased, underscore-joined keys of `ApplicationConfig[...]` (e.g. `ENV["ALMA_API_API_KEY"]` for `[:alma_api, :api_key]`) **overrides** `config/application.yml`.
- The filter of a list lives in its URL; the browser tab remembers it, the session holds none. A filtered list uses `Filterable` (see its header comment).
- Admin forms that open in a modal over their list use `Admin::ModalForm` (see its header comment).
- Mails are grouped by recipient (`ParticipantMailer`, `TeamMailer`), plain text only; their templates live under `app/views/mailers/`.
- Recurring jobs run on Solid Queue from `config/recurring.yml`. The README covers the jobs service on the servers, its monitoring and anonymizing a stage.

## Testing

Minitest, run in parallel, without fixtures: each test creates its own records. Most behaviour is covered by integration tests per area (`test/integration/{admin,frontend,account}`). A test reads like the existing ones: a comment above the class says what the area is for, the test names describe behaviour in plain English. Before writing a helper, look in `test/support/`: there are helpers for the Alma logins, the offer → event → registration chain, config values, the state of Solid Queue and Turbo stream requests (`TURBO_STREAM_HEADERS`; `assert_select` reaches into the `<template>` of a `<turbo-stream>`).

System tests (`test/system`, headless Chrome) cover what only a browser shows, such as modals. `bin/rails test` leaves them out; `bin/rails test:system` runs them against the built assets, so run `bun run build` first. A Bootstrap modal ignores a close while it is still opening: wait for it to have the focus first (`wait_for_transitions`).

## Claude Code

- `CLAUDE.md` imports this file, so Claude Code reads it whatever its version. Rules go into this file, not into
  `CLAUDE.md`. Personal instructions go into `CLAUDE.local.md` (ignored) or `~/.claude/CLAUDE.md`.
- `.claude/settings.json` turns on the superpowers plugin from the official marketplace but does not install it.
  Install it once with `/plugin install superpowers@claude-plugins-official`.
- Auto memory is personal. A rule for everyone belongs in this file.
