# CMS as AI — Data Model & Database Schema

**Version:** 1.0  
**Target:** Phase 1 + future extensibility

## 1. Modeling Principles

```text
Evidence is immutable where possible
Knowledge is versioned
Facts are temporal
Content is separate from Knowledge
Actions are auditable
Scores are reproducible
LLM output is not truth
PostgreSQL is the primary state store
```

## 2. Core Domains

```text
Sites
Sources
Evidence
Knowledge
Entities
Verification
Content
Search
Opportunities
Actions
Policies
Memory
Evaluation
```

## 3. sites

```text
sites
- id
- name
- domain
- primary_language
- timezone
- status
- created_at
- updated_at
```

## 4. sources

```text
sources
- id
- site_id
- source_type
- name
- external_id
- config
- trust_level
- enabled
- created_at
- updated_at
```

Examples:

```text
wordpress
slack
gsc
ga4
notion
web
youtube
```

## 5. source_items

```text
source_items
- id
- source_id
- external_id
- source_url
- raw_content
- metadata
- published_at
- fetched_at
- checksum
- created_at
```

## 6. evidence

```text
evidence
- id
- site_id
- source_item_id
- evidence_type
- content
- metadata
- observed_at
- trust_level
- embedding          # optional pgvector
- created_at
```

## 7. signals

```text
signals
- id
- site_id
- signal_type
- subject
- strength
- confidence
- first_seen_at
- last_seen_at
- status
- created_at
```

## 8. entities

```text
entities
- id
- site_id
- entity_type
- canonical_name
- slug
- description
- external_ids
- embedding          # optional
- status
- created_at
- updated_at
```

## 9. entity_aliases

```text
entity_aliases
- id
- entity_id
- alias
- language
- source
- confidence
- created_at
```

## 10. entity_candidates

```text
entity_candidates
- id
- site_id
- candidate_name
- entity_type
- source_item_id
- proposed_entity_id
- confidence
- status
- created_at
```

## 11. entity_merges

```text
entity_merges
- id
- source_entity_id
- target_entity_id
- reason
- approved_by
- created_at
```

## 12. facts

```text
facts
- id
- site_id
- entity_id
- attribute
- value_json
- unit
- confidence
- valid_from
- valid_until
- last_verified_at
- risk_level
- status
- created_at
- updated_at
```

## 13. claims

```text
claims
- id
- site_id
- entity_id
- statement
- confidence
- status
- created_at
- updated_at
```

## 14. relationships

```text
relationships
- id
- site_id
- subject_entity_id
- predicate
- object_entity_id
- confidence
- valid_from
- valid_until
- status
- created_at
```

## 15. observations

```text
observations
- id
- site_id
- entity_id
- observation_type
- statement
- observed_at
- confidence
- created_at
```

## 16. questions

```text
questions
- id
- site_id
- entity_id
- text
- language
- audience_segment
- frequency
- first_seen_at
- last_seen_at
- embedding          # optional
- created_at
```

## 17. problems

```text
problems
- id
- site_id
- entity_id
- text
- severity
- audience_segment
- confidence
- created_at
```

## 18. experiences

```text
experiences
- id
- site_id
- entity_id
- person_id
- location
- experienced_at
- summary
- metadata
- created_at
```

## 19. evidence_links

```text
evidence_links
- id
- evidence_id
- knowledge_type
- knowledge_id
- relation_type
- created_at
```

knowledge_type examples:

```text
Fact
Claim
Observation
Relationship
Experience
```

## 20. knowledge_versions

```text
knowledge_versions
- id
- knowledge_type
- knowledge_id
- version
- snapshot
- change_reason
- changed_by_type
- changed_by_id
- created_at
```

## 21. fact_staleness

```text
fact_staleness
- id
- fact_id
- age_days
- risk_score
- stale_reason
- status
- evaluated_at
```

## 22. verification_requests

```text
verification_requests
- id
- site_id
- fact_id
- entity_id
- request_type
- question
- priority
- assigned_to
- due_at
- status
- created_at
- completed_at
```

## 23. verification_events

```text
verification_events
- id
- verification_request_id
- person_id
- verified_at
- result
- notes
- location
- confidence
- created_at
```

## 24. original_assets

```text
original_assets
- id
- site_id
- verification_event_id
- asset_type
- file_reference
- metadata
- rights_status
- captured_at
- created_at
```

## 25. authors

```text
authors
- id
- site_id
- name
- bio
- profile_url
- same_as
- created_at
```

## 26. author_expertise

```text
author_expertise
- id
- author_id
- topic
- evidence
- level
- created_at
```

## 27. content_items

```text
content_items
- id
- site_id
- content_type
- external_id
- url
- canonical_url
- language
- title
- status
- published_at
- updated_at
- embedding          # optional
```

## 28. content_versions

```text
content_versions
- id
- content_item_id
- version
- title
- body
- metadata
- source
- created_at
```

## 29. content_claims

```text
content_claims
- id
- content_version_id
- statement
- start_offset
- end_offset
- knowledge_type
- knowledge_id
- grounded
- confidence
- review_status
- created_at
```

## 30. passages

```text
passages
- id
- site_id
- primary_question_id
- content
- language
- status
- embedding          # optional
- created_at
- updated_at
```

## 31. passage_knowledge_links

```text
passage_knowledge_links
- id
- passage_id
- knowledge_type
- knowledge_id
- created_at
```

## 32. language_projections

```text
language_projections
- id
- site_id
- cluster_key
- content_item_id
- language
- locale
- hreflang
- created_at
```

## 33. content_graph_edges

```text
content_graph_edges
- id
- site_id
- from_content_item_id
- to_content_item_id
- edge_type
- anchor_text
- source
- created_at
```

## 34. queries

```text
queries
- id
- site_id
- query
- language
- intent
- search_volume
- created_at
```

## 35. query_clusters

```text
query_clusters
- id
- site_id
- name
- primary_entity_id
- intent
- created_at
```

## 36. query_cluster_memberships

```text
query_cluster_memberships
- id
- query_cluster_id
- query_id
- created_at
```

## 37. rankings

```text
rankings
- id
- site_id
- query_id
- content_item_id
- position
- impressions
- clicks
- measured_at
```

## 38. serp_snapshots

```text
serp_snapshots
- id
- query_id
- captured_at
- raw_result
- features
- created_at
```

## 39. competitor_pages

```text
competitor_pages
- id
- site_id
- query_id
- url
- domain
- title
- position
- content_features
- captured_at
```

## 40. content_decay

```text
content_decay
- id
- content_item_id
- traffic_change
- ranking_change
- ctr_change
- decay_score
- evaluated_at
```

## 41. cannibalization_pairs

```text
cannibalization_pairs
- id
- site_id
- query_cluster_id
- content_item_a_id
- content_item_b_id
- overlap_score
- severity
- status
- created_at
```

## 42. url_redirects

```text
url_redirects
- id
- site_id
- source_url
- target_url
- redirect_type
- status
- created_at
```

## 43. index_status

```text
index_status
- id
- content_item_id
- indexed
- canonical_url
- coverage_status
- checked_at
```

## 44. goals

```text
goals
- id
- site_id
- name
- description
- metric
- target_value
- target_date
- status
- created_at
```

## 45. strategies

```text
strategies
- id
- goal_id
- name
- description
- created_by
- status
- created_at
```

## 46. opportunities

```text
opportunities
- id
- site_id
- opportunity_type
- entity_id
- content_item_id
- query_cluster_id
- score
- score_components
- explanation
- status
- created_at
```

## 47. suppressions

```text
suppressions
- id
- site_id
- opportunity_id
- suppression_type
- score
- reason
- status
- created_at
```

## 48. plans

```text
plans
- id
- site_id
- strategy_id
- opportunity_id
- hypothesis
- expected_result
- observation_window
- status
- created_at
```

## 49. actions

```text
actions
- id
- site_id
- plan_id
- action_type
- target_type
- target_id
- payload
- risk_level
- autonomy_level
- status
- created_at
- executed_at
```

## 50. action_results

```text
action_results
- id
- action_id
- result
- success
- metrics_before
- metrics_after
- rollback_required
- created_at
```

## 51. review_tasks

```text
review_tasks
- id
- site_id
- reviewable_type
- reviewable_id
- review_type
- priority
- status
- assigned_to
- decision
- notes
- created_at
- completed_at
```

## 52. campaigns

```text
campaigns
- id
- site_id
- name
- description
- started_at
- completed_at
- status
```

## 53. campaign_actions

```text
campaign_actions
- id
- campaign_id
- action_id
- created_at
```

## 54. policies

```text
policies
- id
- site_id
- policy_type
- key
- value
- enforcement
- enabled
- created_at
- updated_at
```

## 55. site_policies

```text
site_policies
- id
- site_id
- max_new_pages_per_week
- max_pages_changed_per_day
- max_site_change_ratio
- max_redirects_per_batch
- max_links_changed_per_day
- created_at
- updated_at
```

## 56. capability_autonomy

```text
capability_autonomy
- id
- site_id
- capability
- autonomy_level
- success_count
- rejection_count
- rollback_count
- updated_at
```

## 57. memories

```text
memories
- id
- site_id
- memory_type
- subject_type
- subject_id
- content
- confidence
- expires_at
- created_at
```

memory_type:

```text
operational
strategic
policy
```

## 58. evaluation_cases

```text
evaluation_cases
- id
- eval_type
- input_data
- expected_output
- metadata
- created_at
```

## 59. evaluation_runs

```text
evaluation_runs
- id
- model
- eval_type
- started_at
- completed_at
- score
- metadata
```

## 60. evaluation_results

```text
evaluation_results
- id
- evaluation_run_id
- evaluation_case_id
- actual_output
- score
- passed
- created_at
```

## 61. citation_checks

Future AI Search tracking:

```text
citation_checks
- id
- site_id
- query
- platform
- cited
- cited_url
- checked_at
```

## 62. visibility_checks

```text
visibility_checks
- id
- site_id
- query
- platform
- visibility_score
- details
- checked_at
```

## 63. deployment_settings

Optional PaaS / runtime configuration.

```text
deployment_settings
- id
- site_id
- runtime_type
- worker_enabled
- scheduler_enabled
- vector_search_enabled
- object_storage_enabled
- created_at
- updated_at
```

`runtime_type`例:

```text
render
railway
heroku
fly
docker
```

Application自体はPaaS非依存に保つ。

## 64. connector_credentials

SecretそのものではなくSecret Manager参照情報を保持する想定。

```text
connector_credentials
- id
- source_id
- credential_type
- secret_reference
- status
- created_at
- updated_at
```

DBへ平文Secretを保存しない。

## 65. Critical Relationships

```text
Site
├── Sources
├── Entities
├── Content
├── Queries
├── Policies
└── Goals
```

```text
Source
↓
Source Item
↓
Evidence
↓
Knowledge
```

```text
Knowledge
↓
Content Claims
↓
Content
```

```text
Observation
↓
Opportunity / Suppression
↓
Plan
↓
Action
↓
Action Result
```

## 66. Important Constraints

Application / DB Layerで保証する。

```text
Fact cannot become trusted truth without provenance
Action cannot execute without policy evaluation
Content Claim preserves grounding status
Knowledge updates create versions
Entity merges are auditable
Redirects cannot loop
Only one canonical owner per managed field
Secrets are not stored in plaintext
```

## 67. Indexing Strategy

```text
facts(entity_id, attribute)
facts(last_verified_at)

evidence(source_item_id)

entity_aliases(alias)

content_items(url)
content_items(external_id)

queries(query)

rankings(query_id, measured_at)

opportunities(site_id, status, score)

actions(site_id, status)

verification_requests(status, priority)
```

## 68. Vector Columns

pgvectorはOptional。

Candidate:

```text
evidence.embedding
entities.embedding
questions.embedding
content_items.embedding
passages.embedding
```

Core Applicationはpgvector無しでも起動可能にする。

## 69. JSONB Usage

```text
source_items.raw_content
source_items.metadata
facts.value_json
entities.external_ids
opportunities.score_components
actions.payload
```

主要検索条件をJSONBへ逃がしすぎない。

## 70. Multi-tenancy

主要テーブルにはsite_idまたはtenant_idを持たせる。

Tenant間Knowledge混入を防ぐ。

## 71. Auditability

重要Mutation:

```text
who
what
when
why
before
after
```

を追跡可能にする。

## 72. Phase 1 Minimum Tables

```text
sites
sources
source_items
evidence

entities
entity_aliases
facts
claims
evidence_links
knowledge_versions

content_items
content_versions
content_claims

queries
rankings

fact_staleness
verification_requests
verification_events

opportunities
suppressions
plans
actions
action_results
review_tasks

policies
site_policies
memories
```

## 73. Phase 1.5

```text
relationships
questions
problems
experiences
content_graph_edges
content_decay
cannibalization_pairs
url_redirects
index_status
```

## 74. Later Phase

```text
passages
language_projections
serp_snapshots
competitor_pages
campaigns
experiments
citation_checks
visibility_checks
deployment_settings
```

## 75. PaaS Data Principle

必須Stateful Componentは原則PostgreSQLのみ。

初期必須にしない:

```text
Redis
Neo4j
Elasticsearch
Kafka
Dedicated Vector DB
Persistent Disk
```

Object StorageもPhase 1ではOptional。

## 76. Data Model Philosophy

このデータモデルの目的はKnowledge Graphを作ることではない。

目的は、

> **AIが何を知り、何を知らず、何を根拠に判断し、何を変更し、その結果どうなったかを追跡できること**

である。

これがCMS as AIの状態そのものになる。
