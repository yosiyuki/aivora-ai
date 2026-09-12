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
`PGHOST=localhost PGPORT=5433 PGUSER=postgres PGPASSWORD=postgres`. The `postgres` service bundles
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
