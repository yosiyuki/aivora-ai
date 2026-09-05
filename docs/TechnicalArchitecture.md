# CMS as AI
## Technical Architecture

**Version:** 0.9

---

# 1. Architecture Goal

CMS as AIは単一LLMアプリケーションではない。

全体を、

```text
Sensors
↓
Evidence
↓
Knowledge
↓
World Model
↓
Decision Engines
↓
Planning
↓
Policy
↓
Tools
↓
Actions
↓
Evaluation
```

として構成する。

---

# 2. Core Architecture

```text
                    Business Goals
                          ↓
                  Feasibility Model
                          ↓
                   Human Strategy
                          ↓

              ┌─────────────────────┐
              │     CMS Brain       │
              │                     │
              │ World Model         │
              │ Hybrid Knowledge    │
              │ Search World        │
              │ Content Graph       │
              │ Technical State     │
              │ Memory              │
              │ Policy              │
              │ Evaluation          │
              └─────────────────────┘
                 ↑             ↓
              Sensors       Decisions
                 ↑             ↓
                              Actions
```

---

# 3. System Components

主要コンポーネント：

```text
Connector Layer
Ingestion Pipeline
Evidence Store
Knowledge Layer
Entity Resolution
World Model
Search Intelligence
Opportunity Engine
Suppression Engine
Pruning Engine
Verification Engine
Content Grounding Engine
Technical SEO Engine
Planner
Policy Engine
Tool Runtime
Review System
Evaluation System
Memory
```

---

# 4. Connector Layer

外部システムとの接続を担当する。

Phase 1：

```text
WordPress Connector
Search Console Connector
GA4 Connector
Slack Connector
```

Later：

```text
Notion
Obsidian
CRM
YouTube
Google Trends
SNS
```

---

# 5. Ingestion Architecture

```text
External Source
↓
Connector
↓
Raw Source Item
↓
Normalizer
↓
Evidence Extraction
↓
Candidate Knowledge
```

Raw Dataと加工済みデータを分離する。

---

# 6. Trust Boundary

外部Sourceはすべて、

```text
UNTRUSTED
```

として扱う。

特に、

```text
Slack
External Web
SNS
Comments
User-generated content
```

はPrompt Injectionの可能性を持つ。

---

# 7. Agent Isolation

```text
Untrusted Input
↓
Extraction Agent
NO ACTION TOOLS
↓
Structured Output
↓
Validation
↓
Knowledge
↓
Planning Agent
↓
Action Agent
↓
Policy Engine
↓
Tools
```

Action AgentにはRaw External Inputを直接渡さない。

---

# 8. Extraction Agent

責務：

- Entity Candidate抽出
- Fact Candidate抽出
- Claim抽出
- Question抽出
- Problem抽出
- Observation抽出
- Experience抽出

Tool権限：

```text
NONE
```

構造化出力を必須とする。

---

# 9. Entity Resolution Service

Entity CandidateをCanonical Entityへ解決する。

判定要素：

```text
Name similarity
Alias
Location
URL
External IDs
Context
Embedding similarity
Structured attributes
```

曖昧な場合はReview Taskを生成する。

---

# 10. Hybrid Knowledge Layer

Knowledgeは、

```text
Structured
+
Unstructured
```

で保持する。

Structured：

```text
Entity
Fact
Relationship
```

Unstructured：

```text
Evidence
Observation
Experience
Question
Problem
Claim
Embedding
```

---

# 11. Provenance Architecture

KnowledgeとEvidenceを多対多で接続する。

```text
Knowledge
↕
Evidence Links
↕
Evidence
```

Factの更新時も旧Evidenceは保持する。

---

# 12. Temporal Knowledge

Factは時間性を持つ。

```text
valid_from
valid_until
last_verified_at
```

現在値だけを上書きしない。

履歴はKnowledge Versionとして保存する。

---

# 13. World Model

World Modelは以下から構成する。

```text
Business World
Audience World
Knowledge World
Content World
Search World
Technical World
Performance World
```

専用Graph DBはPhase 1必須ではない。

PostgreSQLを主データストアとしてよい。

---

# 14. Search World

Search Intelligenceは、

```text
Queries
Query Clusters
Search Intent
Rankings
SERP Snapshots
Competitors
Content Gaps
Search Demand
```

を保持する。

Search WorldはOpportunity判定に利用する。

---

# 15. Content Graph

Knowledge Graphとは分離する。

```text
Knowledge Graph
= 世界の意味

Content Graph
= Web上の配置
```

Content Graph：

```text
Pages
Passages
Internal Links
Topic Clusters
Language Relations
Canonical Relations
Redirect Relations
```

---

# 16. Opportunity Engine

特徴量を生成し、

```text
Opportunity Score
```

をコードで算出する。

例：

```text
Demand
Business Value
Authority Fit
Information Gain
Freshness Need
Internal Signal
Feasibility
Competition
Cannibalization
Content Cost
Quality Risk
```

LLMは説明を担当するがScore決定はしない。

---

# 17. Suppression Engine

Opportunityに対する抑制要因を計算する。

```text
Low Information Gain
High Cannibalization
Low Win Probability
Excessive Publishing Rate
Insufficient Evidence
Policy Risk
Duplicate Intent
```

Opportunity Scoreが高くてもSuppressionが閾値超過なら実行しない。

---

# 18. Pruning Engine

既存Contentを監視する。

入力：

```text
Traffic
Rankings
CTR
Backlinks
Fact Staleness
Query Overlap
Index Status
```

出力：

```text
KEEP
UPDATE
MERGE
NOINDEX
REDIRECT
DELETE CANDIDATE
```

---

# 19. Verification Engine

Fact StalenessやConflictを検出する。

```text
Fact
↓
Risk Evaluation
↓
Verification Request
↓
Human / External Verification
↓
Evidence
↓
Fact Update
```

---

# 20. Content Grounding Engine

```text
Knowledge
↓
Draft
↓
Claim Extraction
↓
Knowledge / Evidence Match
↓
Unsupported Claim Detection
```

Content Claim単位で根拠を保持する。

---

# 21. Passage Layer

ProjectionはPage単位だけでなく、

```text
Answer Block / Passage
```

を持つ。

```text
Question
↓
Knowledge
↓
Answer Block
↓
Article / FAQ / Chatbot / SNS
```

---

# 22. Technical SEO Engine

状態として以下を管理する。

```text
URL
Canonical
Redirect
hreflang
Sitemap
Schema
Index Status
Rendering
Core Web Vitals
Internal Link Graph
```

---

# 23. WordPress Adapter

Phase 1では、

```text
WordPress
↓
CMS as AI
```

が基本。

WordPress Field Ownershipを明示する。

例：

```text
Title → WordPress
Body → WordPress
Canonical → SEO Plugin
Schema → CMS as AI
```

など。

複数システムが同じFieldを書かない。

---

# 24. Avoid Bidirectional Sync

Phase 2でも無制限な双方向同期は避ける。

設計原則：

```text
One domain
One canonical owner
```

---

# 25. Planner

PlannerはHuman Strategyを短期Actionへ分解する。

```text
Strategy
↓
Opportunity
↓
Plan
↓
Tasks
```

LLMの長期戦略判断には依存しない。

---

# 26. Feasibility Engine

Goalに対して、

```text
Search Demand
Reachable Ranking
Expected CTR
Expected Conversion
Time Horizon
```

等から達成可能性を推定する。

達成困難なGoalには修正案を返す。

---

# 27. Policy Engine

LLMの外側で実装する。

```text
Action
↓
Operational Policy
↓
Editorial Policy
↓
Aggregate Policy
↓
Risk Decision
```

結果：

```text
ALLOW
REVIEW
DENY
FREEZE
```

---

# 28. Tool Runtime

LLMからDBや外部サービスを直接触らせない。

```text
LLM
↓
Typed Tool
↓
Policy Engine
↓
Transaction
↓
Audit Log
```

---

# 29. Tool Categories

```text
content.*
seo.*
link.*
redirect.*
canonical.*
index.*
schema.*
analytics.*
search.*
wordpress.*
deploy.*
verification.*
```

---

# 30. Example Tools

```text
content.edit
content.merge
content.archive

link.create
link.remove

redirect.create

canonical.set

index.noindex

schema.update

wordpress.preview
wordpress.publish

verification.request
```

---

# 31. Review System

Medium / High Risk Actionは、

```text
Proposal
↓
Diff
↓
Evidence
↓
Reason
↓
Human Review
```

を表示する。

Review結果はMemoryへ保存する。

---

# 32. Earned Autonomy

CapabilityごとにAutonomy Levelを持つ。

```text
site_id
capability
autonomy_level
```

例：

```text
Schema → Level 4
Internal Linking → Level 2
Content Edit → Level 1
Deletion → Level 0
```

---

# 33. Aggregate Policy Engine

単体Actionに加え、

```text
Site-wide Change Rate
Batch Size
Daily Action Count
Publishing Rate
```

を評価する。

---

# 34. Emergency Stop

以下でAutomationをFreezeする。

```text
Traffic anomaly
Index anomaly
Mass 404
Manual action
Large redirect spike
Large rollback rate
```

Freeze状態ではAction Toolを拒否する。

---

# 35. Campaign Model

複数Actionを、

```text
Campaign
```

としてまとめる。

これにより、

```text
Campaign Rollback
```

を実現する。

---

# 36. Memory

Phase 1で重視するのはOperational Memory。

```text
Proposal
Acceptance
Rejection
Edit
Rollback
Reason
Approver
```

Strategic Memoryは補助的に扱う。

---

# 37. Evaluation Architecture

Eval Datasetを別途保持する。

対象：

```text
Extraction
Entity Resolution
Fact Classification
Claim Grounding
Opportunity Ranking
Suppression
```

モデル変更時はRegression Evalを実行する。

---

# 38. Background Processing

リアルタイム処理に寄せすぎない。

```text
Cron
Batch Jobs
Event Jobs
```

を使い分ける。

例：

```text
Nightly Knowledge Refresh
Daily GSC Import
Weekly Content Decay Analysis
Hourly Verification Response Processing
```

---

# 39. Model Routing

モデルは用途別に使い分ける。

```text
Small Model
→ classification / extraction

Mid Model
→ entity resolution / summarization

Strong Model
→ planning / complex reasoning / drafting
```

---

# 40. Vector Search

Embeddingは、

- Evidence Search
- Similar Content Detection
- Entity Candidate Matching
- Question Clustering

に使う。

KnowledgeのTruth判定をEmbeddingだけに依存しない。

---

# 41. Recommended Phase 1 Stack

一例：

```text
Rails
PostgreSQL
pgvector
Sidekiq / Solid Queue
LLM APIs
WordPress REST API
Google Search Console API
GA4 API
Slack API
```

---

# 42. Phase 1 Deployment Shape

初期はMicroservices化を避ける。

```text
Modular Monolith
```

で十分。

Bounded Contextだけ明確にする。

例：

```text
Ingestion
Knowledge
Search Intelligence
Content
Automation
Policy
Evaluation
```

---

# 43. Observability

最低限、

```text
Job status
LLM usage
Tool calls
Policy denials
Action errors
Extraction failures
Rollback events
```

を監視する。

---

# 44. Security

必須：

```text
Tenant isolation
Secrets management
Audit log
Role-based permissions
Tool allowlists
Rate limits
Prompt injection isolation
```

---

# 45. Final Architecture Principle

> **LLMは賢さを提供するが、権限・真実・状態・ルールはLLMの外側に置く。**

この原則を崩さない。