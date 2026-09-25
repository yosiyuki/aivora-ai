# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository state

A Rails 8.1 application (Ruby 4.0, PostgreSQL 18, Solid Queue) whose specification set is checked in
alongside it (all at Version 2.0):

- `README.md` — product requirements for Phase 1 (AI Publishing System)
- `docs/TechnicalArchitecture.md` — 53 sections: components, agent isolation, policy/tool runtime, cost
  control, deployment shape
- `docs/DatabaseSchema.md` — 65 table definitions (§3–§67), indexes, pgvector/JSONB usage, phased rollout

These three documents are the source of truth. When implementing anything, read the relevant section
first — table names, column names, engine names, and decision enums are already fixed there.

Application shape is a **modular monolith** (`TechnicalArchitecture.md` §50), not microservices — keep
bounded contexts (Ingestion, Knowledge, Search Intelligence, Content, Automation, Policy, Evaluation)
separated inside one app.

Docs are written in Japanese; match that language when editing them.

Views are **Slim** (`slim-rails`); generators are configured for it and a view spec fails on any
`.html.erb`. `.text.erb` (mailer text) and `.json.erb` are the only ERB allowed.

## Commands

```bash
bin/setup                                  # first run: bundle, db:prepare
bin/rails server                           # admin/review UI + public pages (APP_ROLE=web)
APP_ROLE=public bin/rails server           # public pages only
bin/jobs                                   # worker + scheduler in one process (fine for development)
bundle exec rspec spec/path/to_spec.rb:LINE  # run only what you changed; CI runs the full suite
bundle exec rspec --tag ~slow              # everything except system specs
bin/rubocop                                # lint (rubocop-rails-omakase)
bundle exec slim-lint app/views            # lint templates (views are Slim, never ERB)
bin/brakeman --no-pager                    # security scan
docker build -t aivora-ai .                # the image is a deliverable; keep it building
docker compose up --build                  # PaaS shape locally: db + web + public + worker + scheduler
```

Local PostgreSQL: `docker compose up db` starts PostgreSQL 18 on port 5433; point at it with
`PGHOST=localhost PGPORT=5433 PGUSER=postgres PGPASSWORD=postgres`. `dotenv-rails` loads `.env.local`
(gitignored) in development and test, so `LLM_API_KEY` and the `PG*` variables can live there; specs
tagged `:live` still need `LIVE_LLM=1` on the command line. The `postgres` service bundles
pgvector but nothing enables it — PostgreSQL alone is the requirement.

## Deployment shape (load-bearing)

`PaaS-first, Docker-portable` is an architecture requirement, not an ops detail (`TechnicalArchitecture.md`
§40–47). It decides what the app may depend on:

- **PostgreSQL is the only stateful dependency.** No Redis, Elasticsearch, Neo4j, Kafka, vector DB,
  persistent disk. Solid Queue tables live in the primary database — there is deliberately no separate
  `queue` database and no `connects_to`. `spec/config/deployment_constraints_spec.rb` fails if any of
  this regresses.
- **One image, five commands.** `bin/process {web|public|worker|scheduler|release}` is the only
  entrypoint; `Procfile` maps them for PaaS. `web` and `public` are the same Rails server with different
  route sets (`config/routes/admin.rb` is drawn only when `AppRole.web?`). On a PaaS that cannot split
  traffic, run `web` alone — it serves both.
- **Three environment variables boot production:** `DATABASE_URL`, `APP_SECRET`, `LLM_API_KEY`. No
  Rails credentials, no `RAILS_MASTER_KEY`. `LLM_API_KEY` is read at boot but not required to boot.
- Keep PaaS-specific files (`render.yaml`, `fly.toml`) out of the repository.

## Auth and first-run setup

Authentication is Rails 8's built-in generator output (`has_secure_password`, a `sessions` table, the
`Authentication` concern), not Devise. `ApplicationController` includes it, so **every controller requires
login by default**; public-facing controllers must opt out with `allow_unauthenticated_access`.

- `/setup` is the only way to create the administrator: two steps (admin, then site), reachable only
  while no user or no site exists, 404 afterwards. There is no seed and no CLI for this.
- One user, one `Site` row. `Site.current` returns it; `Current.site` is set for every request.
- No password-reset email — SMTP is not a boot requirement. Recovery is
  `bin/rails users:reset_password[email]`, which prints a new password and ends existing sessions.
- Login, logout and setup routes live in `config/routes/admin.rb`, so the public role has none of them.
- UI strings are Japanese (`config/locales/ja.yml`, default locale `ja`, `rails-i18n` for validation
  messages).
- System specs (`spec/system/`) run on Capybara `rack_test` — no browser. Tag an example `js: true` only
  when it really needs one, and prefer request specs for anything that is not a user journey.

## What this product is

**CMS as AI is itself the output CMS** — it generates pages and serves them (`README.md` §1, §3;
`TechnicalArchitecture.md` §22). This is the single most important thing to understand, because v1.0 of
these documents said the opposite ("既存CMSを置き換えない") and that framing is now withdrawn.

Consequences that trip people up:

- **WordPress is an optional input source, not the source of truth and not a write target.** It has no
  special status among connectors (§24). There is no write-back, no field ownership negotiation, no
  bidirectional sync problem — all of that is gone.
- **Every connector is optional.** The system must work with zero input sources connected.
- **Users are assumed to have no professional skill** (`README.md` §5) — not SEO specialists, not media
  operators. "何かを発信したい人". Never surface jargon, thresholds, or scores as primary UI.

## Architecture invariants

**LLMs provide intelligence, never authority.** Truth, policy, state, and permissions live outside the model
(`TechnicalArchitecture.md` §1, §53). Scores are computed in code; the LLM may explain but not decide
(§15, §16). Every mutation goes `LLM → typed tool → Policy Engine → transaction → audit log` (§27).

**Agent isolation against prompt injection.** All external sources are UNTRUSTED (§6). The pipeline is
`untrusted input → Extraction Agent (NO action tools) → structured output → validation → Knowledge →
Planning Agent → Action Agent → Policy Engine → Tools` (§7). The Action Agent never reads raw external
evidence directly.

**Extraction alone does not create truth.** `Source → Raw Item → Evidence/Signal → Candidate Knowledge →
Validation → Knowledge` (`README.md` §10). An LLM extraction is a *candidate*.

**Nothing is physically deleted** (`README.md` §23; `DatabaseSchema.md` §1, §69). PRUNE means unpublish +
noindex + campaign record; MERGE keeps the source article's body and points canonical at the target. This
is load-bearing: it is what makes autonomous operation without human approval recoverable.

In code this is the `NeverDeleted` concern, included by every model holding knowledge, provenance,
published content, or the record of asking the owner something. Say it directly rather than relying on
`dependent: :restrict_with_exception` — that only made a row undeletable *while it happened to have
dependents*, so deleting a fact's `knowledge_versions` first made the fact deletable again. Tables that
are meant to churn (Solid Queue, sessions, sources, interviews, `llm_usage`, site configuration) stay
deletable, and `spec/models/never_deleted_spec.rb` fails if that line moves either way.

- **`knowledge_versions` is append-only in both directions** — never rewritten, never removed. Every
  other knowledge row leans on having a version, so a deletable version would unlock deleting the
  knowledge too.
- **Nothing cascades off an `Entity`.** `dependent: :nullify` on its claims and experiences used to
  strip a row's subject while keeping the row — information lost with no record that anything happened.
  Combining entities is MERGE, not severed references.
- Guards run on the ActiveRecord path only. `delete_all` and raw SQL skip callbacks;
  `spec/lib/knowledge_bypass_spec.rb` scans all of `app/` and `lib/` to keep them out of the codebase,
  and database triggers are #45.

**Human operation is required at initial setup only** (`README.md` §27, §31). There is no per-action
approval queue. The Review UI is an **after-the-fact observation surface**, not an approval gate
(`TechnicalArchitecture.md` §30), and it never offers content editing. Because individual review is gone,
**Aggregate Policy and Emergency Stop are the only safety mechanisms** — keep their defaults conservative
(§32).

**Verifiable claims without grounding must not be published.** Claims are classified
`verifiable | experiential | general` (`README.md` §20, `claims.claim_kind`). A verifiable claim with no
backing Knowledge is left **blank and raises a Verification Request** — never filled by guessing. This is
the core quality mechanism, since Human Review is absent.

**Knowledge is provenanced, versioned, and temporal.** In code: models include `Versioned` (every
create/update appends a `knowledge_versions` snapshot) and `Evidenced` (`add_evidence!`, `provenanced?`).
`Fact#accept!(evidence:)` is the only way a fact becomes accepted — the validation refuses `accepted`
without an evidence link — and `Fact#supersede!` closes the old fact's validity window instead of editing
it. `EntityCandidate#promote!` is the only way a candidate becomes an `Entity`. `EvidenceLink` and `Evidence`
are read-only once persisted. **Never use `delete`, `delete_all`, `update_all`, `update_columns`,
`insert_all` or `upsert_all` on knowledge tables** — they bypass every one of these guards, and
`spec/lib/knowledge_bypass_spec.rb` fails the build if one appears. Every knowledge row validates that its
associations (entity, source_item) belong to the same site (`SameSite`).
Facts carry `valid_from` / `valid_until` /
`last_verified_at` / `confidence` / `risk_level`; updates create `knowledge_versions` (§11;
`DatabaseSchema.md` §20).

**Multi-tenancy by `site_id`.** Phase 1 is `1 deployment = 1 customer = 1 site`, but the column stays on
every table — dropping it is the one irreversible version of that decision.

## Calling the LLM

`Llm::Client` is the only path to an LLM. Never instantiate the Anthropic SDK elsewhere.

```ruby
Llm::Client.for(:extraction).extract(system:, input:, schema:)   # => Hash, structured output
Llm::Client.for(:drafting).generate(system:, messages:)          # => String
```

- **Operations and models come from `config/llm.yml`** (Model Routing, §37). Phase 1 defaults every
  operation to `claude-opus-5`; lowering extraction to a smaller model is a decision for `llm_usage` data
  (#7), not for a Gemfile-time guess.
- **Extraction can never receive tools.** The adapter interface (`complete(model:, max_tokens:, effort:,
  system:, messages:, schema:)`) has no tools parameter. That is how Agent Isolation (§7) is enforced —
  do not add one. Untrusted text goes in the user turn, never in `system`.
- **Every call writes one `llm_usage` row**, including refusals, truncation, and transport errors
  (`succeeded: false` with the reason in `metadata`). Cost comes from `config/llm_pricing.yml`.
- `stop_reason` is always checked: `refusal` raises `Llm::RefusedError`, `max_tokens` raises
  `Llm::TruncatedError`. Structured output from either is unusable.
- Tests use `Llm::Fake` (`config/llm.yml` sets `adapter: fake` for test). Register a response with
  `Llm::Fake.respond(:extraction) { |call| {...} }`; an unregistered call raises. `Llm::Fake.calls` records
  what was sent. Specs tagged `:live` hit the real API only with `LIVE_LLM=1` and `LLM_API_KEY`.

## Cost is the throttle

Generation volume is bounded by **LLM API cost**, not by article counts or Fact volume
(`README.md` §33; `TechnicalArchitecture.md` §38). Every LLM call is recorded in `llm_usage` — treat that
table as **control data, not telemetry**.

- Observation/maintenance is fixed cost and **never stops**; generation is the variable part. Stopping
  observation means stale facts go undetected and wrong information stays published.
- Budget priority: **Verification → Update → Create**.
- On budget overrun the default is **`degrade`** (switch to smaller models and keep running), not stop.
- **Grounding checks are never skipped, including while degraded.** Prose quality may drop; evidence
  verification may not.
- Present cost to users as outcomes, never as raw spend targets ("月$50なら記事3〜5本"). Users are not
  asked to predict their usage.

In code: the ceiling lives in `site_policies` (`DatabaseSchema.md` §55, reached through `Site#policy`,
which creates the row with the conservative default rather than letting a site run uncapped). That table
is the home of every aggregate limit, not just money — with no per-action approval those caps and
Emergency Stop are the only safety mechanisms.

- `Llm::Budget.for(site)` answers `spent` / `limit` / `exceeded?` / `degraded?`. It is memoised on
  `Current` for the length of a request or job, so generating one page runs the monthly aggregate once
  instead of once per LLM call.
- **Failed calls count against the budget.** A refusal or a truncated answer is still billed and
  `LlmUsage` records the billed cost for exactly that reason, so the aggregate never filters on
  `succeeded`.
- **The month is the site's month.** `Llm::Budget#month_range` wraps `Time.use_zone(site.timezone)`;
  `LlmUsage.this_month` uses `Time.zone` and would shift the boundary by the server's offset.
- **Degrading is configuration, not code.** Each operation in `config/llm.yml` carries a
  `degraded_model`; `Llm::Client.for` picks it when the budget is spent. `grounding` degrades to a mid
  model, never the cheapest — prose may get worse while the budget is spent, evidence verification may
  not. An operation with no `degraded_model` keeps its primary model.
- `budget_action` accepts `degrade | stop` per the schema doc, but **Phase 1 always degrades**
  (`SitePolicy#degrade_only?`). Stopping would stop observation too, and stale facts would go
  undetected while the site keeps serving them.
- Every usage row written by a degraded call carries `metadata["degraded"] = true`. The `model` column
  alone cannot distinguish a degrade from a routing change.

`Llm::Usage::Report.for(site)` turns the month into the sentence the dashboard shows.

- **Only generation spend divides into a per-page figure.** `drafting` / `grounding` / `planning` are
  the variable cost; `extraction` and `entity_resolution` are the fixed cost of observing, and folding
  them in would make a page look far more expensive than it is.
- **A failed version is not a page.** It cost money and bought nothing, so `pages_this_month` counts
  only versions that passed grounding.
- `cost_per_page` returns nil rather than 0 before anything has been generated, and `remaining_pages`
  falls back to README §33's conservative figure. Saying "0 more pages" in a site's first month would
  be wrong.
- `by_operation` exists for model routing review (§37) and is deliberately **not** shown to the owner —
  operation names are our vocabulary, not theirs. The dashboard shows pages, a remaining count, the
  amount in small type, and, while degraded, a sentence saying work continues.

Measured once against a real interview (10 answers) plus one generated page, all on opus: drafting
$0.039, grounding $0.078, so about **$0.12 a page**, against $0.43 for the interview. Two things that
matters for later work: grounding costs twice what drafting does (it writes every claim out as
structured output), and the "$50 buys 3-5 pages" figure is far too conservative — but it stays as the
first-month estimate until operation-phase costs (verification, updates, sensors) can be measured too.

## Onboarding shape

Setup is the only interaction the product requires of a human, and **every question in it is free text
with worked examples — never multiple choice** (`README.md` §27).

Offering options makes users abandon their own vocabulary for yours, and the information dies there.
A checkbox labelled "来てほしい" replaces "常連さんが増えなくて、新しい人にも来てほしい。でも観光客ばかり
だと雰囲気が変わってしまう". Non-experts lack the jargon, not the information. Free-text answers also
become Experiential Claim material directly, so the interview collects Knowledge while it configures the
site — a checkbox answer can never appear in an article, but the user's own words can.

- Attach **three examples of differing length** to each question — as a guide to granularity, not a menu.
- **Infer the archetype; never ask the user to pick one.** Users state purpose through verbs ("来てほしい",
  "残したい", "見てもらいたい"). Ask one clarifying free-text question only when inference fails — archetypes
  compose later and URLs never move, so a perfect first guess is not required.
- **Follow the user's energy first.** Quote their words back ("豆へのこだわり、もう少し聞かせてください")
  before asking administrative things like opening hours; the reverse order loses people.
- **Only the goal is mandatory; Facts and Knowledge are optional.** Goal quantification (`metric` /
  `target_value` / `target_date`) is done by the system.
- **Ask only for `minimum` slots** — what the first article needs. `standard` and `enriched` become
  Verification Requests against the blanks in the published page. Show progress without naming slots
  ("あと少しで最初のページが作れます", never "3/6 充足"), and cap the interview around 10 questions.
- **Route each utterance by kind** (§27.6): intent → `goals` (never Knowledge), fact → Fact, experience →
  Experience. The transcript itself is never stored as Knowledge — intent and fact must not mix.
- Interview answers are external input like any other: the Extraction Agent processes them, with no
  exception to Agent Isolation.
- AI may propose and infer policies, but **Editorial Policy prohibitions are product-fixed and can only be
  tightened, never loosened by the AI** (§30) — an LLM must not author its own constraints.
- Role changes vocabulary, question count, and depth — **it never changes which slots are required**. A
  shop's location is needed whoever runs it.
- First run: **input source present → start by ingesting; absent → generate one article from the interview
  alone**.
- **One structured LLM call per answer.** `Interviewing::Processor` runs `ExtractionAgent` (a single
  `Llm::Client#extract` with `ExtractionSchema`), then `Router` writes intent → `goals`, facts →
  `Fact#accept!` (owner statements are the validation), experiences → `Experience` with the verbatim
  `body`, questions/problems → their tables, and `ArchetypeResolver` decides the archetype in code
  (threshold 0.7, one clarifying question after two low-confidence answers). The model proposes the next
  question; `LlmQuestionSource` only serves it if it carries exactly three examples, else the fixed
  questions take over. An LLM failure marks the turn `failed` and the interview continues.
- **The model's word is not the owner's word.** Every fact, experience and goal in the extraction output
  carries `source_text`, a verbatim span of the answer; `Router` checks it against the raw text
  (whitespace-insensitive). A fact whose span is not in the answer stays a candidate and fills no slot; a
  fact whose span was also classified as intent is dropped; an experience keeps the user's exact span as
  `body`, or the whole raw answer, never a paraphrase.
- **One LLM call per answer is enforced at the database**: `InterviewTurn#claim_for_extraction!` moves
  `pending → processing` with a conditional `update_all`; done and failed are terminal, so a resubmit
  never extracts again. Routing, archetype resolution and the done mark share one transaction.
- Implementation: `Interviewing::Runner` hands out one question at a time from a `QuestionSource`
  (`FixedQuestionSource` asks the fixed opening three — role, topic, purpose — plus generic follow-ups;
  the LLM-backed source lands in #15). Every answer is written twice on purpose: to `interview_turns`
  (conversation state, for resume) and to `source_items` under the owner-trusted `interview` source (the
  only input the Extraction Agent reads). Readiness and the ten-question cap are decided in
  `Interview` / `Runner`, never by the model.

## Generating a page

Two LLM calls per page, then code decides (`app/lib/content/`, README §21):

```text
Content::KnowledgePack.for(site, page_type:)   # code: accepted Facts (F1..), Experiences (E1..), goals, slots
Content::Drafter#draft                          # LLM drafting: Markdown from the pack only; missing facts → [[slot:key]]
Content::ClaimExtractor#extract(body)           # LLM grounding: statements + kind + support ref (structured)
Content::Grounder#ground(body:, claims:)        # code: grounded / blank / excised / general, sentence removal
Content::Generator#generate!                    # one transaction: version + claims, publish! only if passed
```

- The model never sees DB ids — only short refs; `Grounder` resolves refs back through the pack.
- **Grounding is fail-closed.** Every sentence, list item and heading must be covered by a claim; anything
  the extractor did not cover is removed. A verifiable claim is grounded only if the referenced Fact's
  value occurs in the sentence **and the sentence adds no numbers the pack does not know**
  (numeric or one-character values also need their slot label nearby). A sentence in the owner's own
  words is grounded as experiential whatever the model called it, but a reference alone never counts:
  the text must match (`TextNormalizer.covers?` — fragment of the owner's text, or the owner's text
  covering ≥ 80% of the sentence with no new digits). `general` is trusted only for text with nothing
  site-specific in it; numbers, prices, superlatives or the subject's name make it verifiable.
- Ungrounded verifiable → sentence removed, `[[slot:key]]` left when a real slot fits (`blank`),
  otherwise just removed (`excised`). Unknown placeholder keys drop the whole line. A heading that is
  uncovered, ungrounded or carries a placeholder fails the version (short label headings such as
  「どんなお店か」 are structural and kept). A failed version is stored but never published; an LLM error
  creates no version at all.
- **Titles are generated in code** (`Content::Drafter.title_for`: the subject's name, 「よくある質問」…);
  the model's title is never used because it is not grounded and goes into the public `<title>`.
- `Content::KnowledgePack` is scoped to the page's subject (the primary entity) and orders facts by slot
  weight, so truncation drops the least important first.
- Editorial prohibitions (`app/prompts/content/editorial_policy.txt`) are product-fixed and embedded in
  both prompts.
- **Generation runs in the background.** `Interview#complete!` enqueues `Content::GenerateJob` (Active Job
  defers the enqueue to after commit). The job claims the page with a conditional update
  (`ContentItem.claim_for_generation!`, `status: generating`), so duplicate enqueues yield one version; an
  `Llm::Error` becomes a failed version with the error in `metadata`, never a blind retry. In development
  nothing is generated until `bin/jobs` is running; specs use `perform_enqueued_jobs`.
- `/admin/content_items` is observation only: versions, the published one, blanks shown by slot **label**
  (never the key), a single "もう一度作る" button. `Content::Renderer` turns Markdown into sanitised HTML
  and renders `[[slot:key]]` as 「（確認中）」; the public pages use the same renderer.

## Serving the public site

The app is its own output CMS: pages are rendered from the stored version on request, never exported to
disk or pushed elsewhere (`TechnicalArchitecture.md` §22, §45).

- `Public::PagesController` resolves a page by **the URL it was issued** (`ContentItem#url`), never by
  rebuilding a path from params. Only a trailing slash is forgiven. This is what keeps URLs immutable
  (§23) at the serving end.
- **Visibility is `status`, never the pointer.** `ContentItem.published` filters `status: "published"`;
  `unpublish!` keeps `published_version_id` for restore, so a page gated on the pointer would stay
  visible after being unpublished. `draft`, `generating`, `unpublished` and failed-only pages all 404.
- `config/routes/public.rb` ends in a catch-all, so `routes.rb` draws **admin first** — reversing that
  order makes the catch-all swallow every admin path. `spec/config/deployment_constraints_spec.rb`
  fails if it regresses.
- `layouts/public.html.slim` is deliberately separate from the admin layout: the public role has no
  session routes and visitors get none of the admin chrome. It emits `canonical` and `lang`, and
  **no meta description** — a summary of the body would be ungrounded text (README §20).
- `Public::Navigation.for(site)` derives the menu from the archetypes' `page_structure`, keeping only
  page types that have a published item, labelled through `page_types` in `ja.yml` (users never see a
  page type key). Adding an archetype adds entries; it never moves an existing URL.
- **Blanks stay visible on the public page.** 「（確認中）」 is how the owner is asked to fill a
  verifiable fact (README §14); hiding it would remove the mechanism Verification Requests hang off.
- `fresh_when(@version)` is safe because a decided `ContentVersion` is read-only, so its ETag only
  changes when the page is regenerated.

## Asking the owner (Verification Requests)

A verifiable claim with no knowledge is left blank, and the blank is the question (`README.md` §14).
Filling an empty form with entities and facts is beyond a non-expert; answering "what are your opening
hours?" against a page that visibly lacks them is not.

- `Verification::Requester#issue_for(version)` runs after a page is generated. Its sources are the
  blanks in that version **and** the `standard` / `enriched` slots nothing has filled — the first code
  to read those levels, which the interview deliberately never asks for (README §27.3).
- **A blank reaches a page two ways.** The Grounder writes a `content_claims` row; the drafter's own
  `[[slot:key]]` survives into the body with no claim behind it. Anything reading only claims misses
  the second kind, so the requester and the affected-page lookup both check the body too.
- **Priority is a rank, not a score.** `LEVEL_RANK` orders `minimum` → `standard` → `enriched`, weight
  breaks ties. `weight` is defined as the Knowledge Health input (`DatabaseSchema.md` §65), so deriving
  a priority coefficient from it would be our arithmetic, not the product's. The number is never shown.
- **Questions are written in code** (`Verification::Question`), like page titles and editorial
  prohibitions. A generated question would carry assumptions nothing backs. The slot's label is shown,
  never its key.
- **An answer is not knowledge yet.** The form records it verbatim in `verification_events` and stops.
  `Verification::ProcessAnswersJob` does the extraction, so the owner's words survive a model failure
  and are retryable. That split is also what lets a Slack or email channel land later by writing an
  event and nothing else (`README.md` §14, `TechnicalArchitecture.md` §36 "Hourly Verification Response
  Processing").
- The answer takes the interview's path exactly: `SourceItem` under an owner-trust `verification`
  source, `Evidence`, one structured call, then the same `source_text` verbatim check. Without a span
  the fact stays a candidate and fills no slot. An existing accepted fact is **superseded, not edited**.
- **Affected Content Detection** (`TechnicalArchitecture.md` §18): only pages carrying that slot's
  blank are regenerated. Rebuilding everything would spend budget on pages the answer did not touch.
- `verification_events.person_id` is a channel-qualified string (`"user:1"`), the same shape as
  `experiences.person_id`, so Slack ids fit later without a migration. `assigned_to` and `due_at` exist
  as columns per §22 and are not read: one deployment has one owner and no way to notify them.

**Facts go stale on a clock, not on a guess.** `Verification::Staleness` compares `last_verified_at`
against a TTL chosen by `risk_level` (high 90 days, medium 180, low 365) — a wrong opening time sends
someone to a closed door, a wrong description of what a shop is about does not. `risk_level` was set by
the interview router and read by nothing until this.

- **Computed, never stored.** Two columns answer the question at any moment; a stored verdict becomes a
  second truth that disagrees with them the next day. `DatabaseSchema.md` §21 defines `fact_staleness`
  and §75 leaves it out of the Phase 1 minimum, so it stays unbuilt.
- `Fact#mark_stale!` stops publication and **leaves `valid_until` open**: unchecked is not wrong.
  `Fact.current` excludes it, so the page's material loses it and the slot becomes a blank again. The
  published page is not touched and not regenerated — an owner's answer is worth waiting for.
- `Verification::StalenessJob` runs nightly and **calls no model**, which is why observation keeps
  running while the generation budget is spent (README §33). `spec/config/deployment_constraints_spec.rb`
  fails if an `Llm::` call appears in it.
- Answering a recheck re-accepts the fact when the value is unchanged (moving `last_verified_at`, no new
  row) and supersedes it when it moved. `AnswerProcessor#existing_fact` looks for `accepted` **or**
  `stale`; `Fact.current` would miss the stale one and leave a duplicate behind.

## Site structure is derived, never chosen

Site structure comes from the **goal**, not from a user picking a template and not from the LLM inventing
one (`README.md` §28; `TechnicalArchitecture.md` §23).

```text
Q1 role          → vocabulary, depth, whether policy editing is exposed
goal interview   → archetype → page structure + required knowledge slots
```

- The user never sees the word "archetype" — same rule as ontology and entity schema (§27).
- Archetype definitions are **product-fixed YAML** (`config/archetypes/*.yml`, read through
  `ArchetypeDefinition.find(:business)`), not a table — a master in the DB would compete with the
  repository for truth. The LLM only classifies which archetype a goal implies; it never authors
  `page_structure`, slots, or weights. Same reasoning as product-fixed editorial prohibitions.
- Slots carry `level` (`minimum` is asked in the interview; `standard` / `enriched` become Verification
  Requests), `kind` (`verifiable` / `experiential`, the Claim vocabulary) and `weight`.
  `Site#required_slots(level:)` unions the active archetypes, keeping the higher weight for shared keys.
- **A fact answers a slot through `facts.slot_key`, never through `attribute_key`.** `attribute_key` is
  the extraction's own wording in the owner's language ("主な読者"); `slot_key` is the product-fixed
  vocabulary ("audience"). They are different alphabets, so comparing `attribute_key` to a slot key
  never matched and no fact ever filled a slot — a published page showed 「（確認中）」 for a fact the
  site already had. `Fact#fills_slot?` requires `accepted` as well: a candidate is the model's word.
  `supersede!` carries `slot_key` forward, or the replacement would stop filling the slot. Slot weight
  ordering, the pack's labels and the Grounder's blank/excise decision all read `slot_key`.
- Archetypes compose (`site_archetypes`, `is_primary`) — "shop info + blog" is the common case, not an
  edge case.
- **Required slots drive Verification Requests, and their priority is archetype-dependent.** A missing
  opening time is critical for `business` and irrelevant for `media`. Knowledge Health is computed against
  the archetype's slots, not a global list.

**Published URLs are immutable** (`DatabaseSchema.md` §69). In code: `ContentItem` has `attr_readonly :url`
plus a validation that rejects any change; `ContentItem#publish!(version)` accepts only a version whose
`grounding_status` is `passed`; versions are appended and become read-only once grounding is decided;
`unpublish!` changes status and keeps the published pointer. Adding an archetype adds structure; it never
moves an existing URL, and knowledge changes never delete a page (status changes instead). A system that
detects content decay must not generate its own.

## Progressive activation

There is no launch/operation mode switch and **no `mode` state variable** (`README.md` §37;
`DatabaseSchema.md` §76). Each feature checks whether its own prerequisite data exists and enables itself:

```text
Knowledge Health, content generation   → immediately
Verification, Fact staleness           → once Facts exist
Content decay                          → after traffic data
Cannibalization                        → after ranking data
Opportunity / Feasibility              → after GSC connection
```

Do not apply the Information Gain Gate or Feasibility Check during launch — with no accumulated Knowledge
they reject everything, which is why `README.md` §19 and §29 scope them to the operation phase.

## Implementation ordering

`DatabaseSchema.md` §75 lists the Phase 1 minimum tables. Two changes from v1.0 that affect priority:

- **Promoted into the main path:** `questions` / `problems` / `experiences` — they hold Experiential Claims.
- **Demoted to operation phase:** `queries` / `rankings` / `opportunities` / `suppressions`.
- **New and required:** `llm_usage`.

Build the main path first: interview → Knowledge → generation → publishing → verification. Operation-phase
tables (§76) have their schema defined but are enabled later.

Work is background-first, not realtime (`TechnicalArchitecture.md` §36). Model routing (§37): small for
classification/extraction, mid for entity resolution/summarization, strong for planning and drafting.
