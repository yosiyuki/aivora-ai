# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository state

Design-stage repository — **no application code, build system, or tests exist yet**. It currently contains
only the specification set (all at Version 2.0):

- `README.md` — product requirements for Phase 1 (AI Publishing System)
- `docs/TechnicalArchitecture.md` — 53 sections: components, agent isolation, policy/tool runtime, cost
  control, deployment shape
- `docs/DatabaseSchema.md` — 65 table definitions (§3–§67), indexes, pgvector/JSONB usage, phased rollout

These three documents are the source of truth. When implementing anything, read the relevant section
first — table names, column names, engine names, and decision enums are already fixed there.

Planned Phase 1 stack (`TechnicalArchitecture.md` §49): Rails, PostgreSQL, Solid Queue, optional pgvector,
LLM APIs, Docker. Application shape is a **modular monolith** (§50), not microservices — keep bounded
contexts (Ingestion, Knowledge, Search Intelligence, Content, Automation, Policy, Evaluation) separated
inside one app.

Docs are written in Japanese; match that language when editing them.

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

**Knowledge is provenanced, versioned, and temporal.** Facts carry `valid_from` / `valid_until` /
`last_verified_at` / `confidence` / `risk_level`; updates create `knowledge_versions` (§11;
`DatabaseSchema.md` §20).

**Multi-tenancy by `site_id`.** Phase 1 is `1 deployment = 1 customer = 1 site`, but the column stays on
every table — dropping it is the one irreversible version of that decision.

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

The only fixed question is **Q1: the user's role** (`README.md` §27). Everything after it adapts —
vocabulary, depth, whether policy editing is exposed at all (expert / business / individual).

- **Only the goal is mandatory; Facts and Knowledge are optional.**
- Goal quantification (`metric` / `target_value` / `target_date`) is done by the system, not the user.
- AI may propose and infer policies, but **Editorial Policy prohibitions are product-fixed and can only be
  tightened, never loosened by the AI** (§30) — an LLM must not author its own constraints.
- Conversation logs never become Evidence or Knowledge (intent ≠ fact).
- First run: **input source present → start by ingesting; absent → generate one article from the interview
  alone**, then grow Knowledge by having the user fill the blanks via Verification Requests.

## Site structure is derived, never chosen

Site structure comes from the **goal**, not from a user picking a template and not from the LLM inventing
one (`README.md` §28; `TechnicalArchitecture.md` §23).

```text
Q1 role          → vocabulary, depth, whether policy editing is exposed
goal interview   → archetype → page structure + required knowledge slots
```

- The user never sees the word "archetype" — same rule as ontology and entity schema (§27).
- `archetype_definitions` is a **product-fixed master table**. The LLM only classifies which archetype a
  goal implies; it never authors `page_structure`, `required_slots`, or `priority_weights`. Same reasoning
  as product-fixed editorial prohibitions.
- Archetypes compose (`site_archetypes`, `is_primary`) — "shop info + blog" is the common case, not an
  edge case.
- **Required slots drive Verification Requests, and their priority is archetype-dependent.** A missing
  opening time is critical for `business` and irrelevant for `media`. Knowledge Health is computed against
  the archetype's slots, not a global list.

**Published URLs are immutable** (`DatabaseSchema.md` §69). Adding an archetype adds structure; it never
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

## When code lands

Once the Rails app exists, update this file with real build/test/lint commands. Per the user's global
instructions: run only the specs related to a change locally (`bundle exec rspec path/to/spec.rb:LINE`),
never the full suite — CI covers that — and use the `gh` CLI for all GitHub operations.
