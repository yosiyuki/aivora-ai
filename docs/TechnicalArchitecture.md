# CMS as AI — Technical Architecture

**Version:** 2.0  
**Architecture Principle:** PaaS-first, Docker-portable

## 1. Architecture Goal

CMS as AIは単一LLMアプリケーションではない。

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

LLMはReasoning Componentであり、Truth / Policy / State / PermissionsはLLMの外側に置く。

## 2. Core Architecture

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

## 3. Main Components

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
Feasibility Engine
Policy Engine
Tool Runtime
Review System
Evaluation System
Memory
```

## 4. Connector Layer

外部システムとの接続を担当する。**すべて入力専用。**

Phase 1（すべて任意）:

```text
Website Connector（クロール）
Slack Connector
Notion Connector
SNS Connector
WordPress Connector
```

Later:

```text
Search Console
GA4
Obsidian
CRM
Support
YouTube
```

ConnectorsはPlugin的に追加可能にし、Coreと分離する。

入力源が1つも無い状態でも、システムは動作しなければならない。

## 5. Ingestion Pipeline

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
↓
Validation
```

Raw Dataと加工済みKnowledgeを分離する。

## 6. Trust Boundary

以下はすべてUNTRUSTED INPUTとして扱う。

```text
Slack
SNS
External Web
Comments
User-generated content
```

## 7. Agent Isolation

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

**Action AgentはRaw External Evidenceを直接読まない。**

## 8. Extraction Agent

責務:

- Entity Candidate抽出
- Fact Candidate抽出
- Claim抽出
- Question抽出
- Problem抽出
- Observation抽出
- Experience抽出

Tool権限:

```text
NONE
```

Structured Outputを必須とする。

## 9. Entity Resolution Service

判定要素:

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

曖昧な場合はHuman Review。

## 10. Hybrid Knowledge Layer

```text
Structured
├── Entity
├── Fact
└── Relationship

Semi-structured / Unstructured
├── Evidence
├── Observation
├── Experience
├── Question
├── Problem
├── Claim
└── Embedding
```

Graph DBはPhase 1必須にしない。

## 11. Provenance & Temporal Knowledge

Knowledge ↔ Evidenceを多対多で保持する。

Factには:

```text
valid_from
valid_until
last_verified_at
confidence
risk_level
```

を持たせる。

Knowledge更新時はVersionを作成する。

## 12. World Model

```text
Business World
Audience World
Knowledge World
Content World
Search World
Technical World
Performance World
```

PostgreSQLを主データストアとする。

## 13. Search World

```text
Queries
Query Clusters
Search Intent
Rankings
SERP Snapshots
Competitors
Content Gaps
Search Demand
Visibility
```

## 14. Content Graph

```text
Knowledge Graph
= 意味・世界認識

Content Graph
= Web上の配置
```

Content Graph:

```text
Pages
Passages
Internal Links
Topic Clusters
Language Relations
Canonical Relations
Redirect Relations
```

## 15. Opportunity Engine

特徴量からScoreをコード計算する。

例:

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

LLMは説明・特徴抽出を担当するがScore決定はしない。

## 16. Suppression Engine

```text
Low Information Gain
High Cannibalization
Low Win Probability
Excessive Publishing Rate
Insufficient Evidence
Policy Risk
Duplicate Intent
```

Opportunityが高くてもSuppressionが高ければ実行しない。

## 17. Pruning Engine

入力:

```text
Traffic
Rankings
CTR
Backlinks
Fact Staleness
Query Overlap
Index Status
```

出力:

```text
KEEP
UPDATE
MERGE
NOINDEX
REDIRECT
DELETE CANDIDATE
```

## 18. Verification Engine

```text
Fact
↓
Staleness / Conflict Evaluation
↓
Verification Request
↓
Human Verification
↓
Evidence
↓
Fact Update
↓
Affected Content Detection
```

## 19. Content Grounding Engine

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

Content Claim単位でGrounding状態を保持する。

## 20. Passage Layer

```text
Question
↓
Knowledge
↓
Answer Block / Passage
↓
Article / FAQ / Chatbot / SNS
```

Pageより小さいProjection単位を持つ。

## 21. Technical SEO Engine

Stateとして以下を管理する。

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

## 22. Publishing Layer

**CMS as AI 自身が出力CMSであり、ページを生成し配信する。**

```text
Knowledge
↓
Passage / Answer Block
↓
Page
↓
Publishing Layer
↓
HTTP Response
```

配信はアプリケーション内で行う（§40）。静的生成・外部CDNを前提としない。

```text
1 deployment = 1 customer = 1 site
単一ドメインで配信する
```

サブドメイン発行・中央DNSを必要としない。

## 23. Site Structure Derivation

サイト構造は Goal から導出する。

```text
目的ヒアリング
↓
Archetype 判定（LLM）
↓
archetype_definitions（製品固定マスタ）
↓
├── page_structure   → 生成すべきページ
└── required_slots   → Verification Request の生成元
```

LLM が行うのは Archetype の**判定のみ**。
構造・スロット・優先度は製品が保持し、LLM に生成させない。

```text
一度発行した URL は不変
```

Archetype 追加時も既存 URL を変更しない。構造は足せるが動かさない。

## 24. Input Connectors

外部システムは**入力源**であり、書き戻し先ではない。

```text
Website / Slack / Notion / SNS / WordPress
↓
CMS as AI
```

すべて任意。入力源が1つも無くても運用を開始できる。

**WordPress Connector は Optional機能**であり、
他のConnectorに対して特別な地位を持たない。

一方向（外部 → CMS as AI）のみとし、外部システムへの書き込みを行わない。
これにより Field Ownership の衝突が構造的に発生しない。

## 25. Planner

```text
Human Strategy
↓
Opportunity
↓
Plan
↓
Tasks
↓
Actions
```

長期Strategyは人間が握り、AIは短期Planningを担当。

## 26. Feasibility Engine

```text
Search Demand
Reachable Ranking
Expected CTR
Expected Conversion
Time Horizon
```

等からGoal達成可能性を評価する。

## 27. Policy Engine

LLMの外側で実装。

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

Result:

```text
ALLOW
REVIEW
DENY
FREEZE
```

## 28. Tool Runtime

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

DBや外部サービスをLLMから直接触らせない。

## 29. Tool Categories

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

## 30. Review System

**Phase 1では個別Actionごとの人間承認を行わない。**

人間の操作は初期設定のみを必須とし、以降は Policy Engine が機械的に適用する。

Review UI は承認キューではなく**事後の観測面**として機能する。

```text
実行されたAction
↓
Diff / Evidence / Reason
↓
観測・監査（事後）
```

コンテンツ編集機能を持たない。既存CMSの管理画面を再現しない。

実行結果はOperational Memoryへ保存する。

## 31. Earned Autonomy

Site × Capabilityで管理する。

```text
Level 0 — Observe
Level 1 — Recommend
Level 2 — Draft
Level 3 — Low-risk Auto
Level 4 — Policy-bounded Autonomous
```

**Phase 1では初期設定で方針を一度与え、以降は個別承認を求めない。**

不可逆な操作を系から排除している（物理削除を行わない）ため、
Level 4 でも Campaign Rollback による回復可能性を維持できる。

`capability_autonomy` は success / rejection / rollback を記録し、
実績に基づく調整を可能にする。

## 32. Aggregate Policy

```text
Site-wide Change Rate
Batch Size
Daily Action Count
Publishing Rate
Redirect Count
Link Change Count
```

を評価する。

**個別承認を行わない設計では、Aggregate Policy と Emergency Stop が
唯一の安全装置となる。既定値は保守的に設定する。**

## 33. Emergency Stop & Campaign Rollback

Trigger:

```text
Traffic anomaly
Index anomaly
Mass 404
Manual action
Redirect spike
Large rollback rate
```

Freeze時はAction Toolを拒否。

複数ActionをCampaignとして束ね、Campaign単位Rollbackを可能にする。

## 34. Memory

Phase 1ではOperational Memory中心。

```text
Proposal
Acceptance
Rejection
Edit
Rollback
Reason
Approver
```

Strategic Memoryは補助的に扱い、Evidence / Confidence / Decayを持たせる。

## 35. Evaluation Architecture

Eval対象:

```text
Extraction
Entity Resolution
Fact Classification
Claim Grounding
Opportunity Ranking
Suppression
```

Model更新時はRegression Evalを実行する。

## 36. Background Processing

リアルタイム処理に寄せすぎない。

```text
Cron
Batch Jobs
Event Jobs
```

例:

```text
Nightly Knowledge Refresh
Daily GSC Import
Weekly Content Decay Analysis
Hourly Verification Response Processing
```

## 37. Model Routing

```text
Small Model
→ classification / extraction

Mid Model
→ entity resolution / summarization

Strong Model
→ planning / complex reasoning / drafting
```

Model Routing はコスト最適化の主要な手段である。
`llm_usage` の operation_type 別集計を用いて配分を見直す。

## 38. Cost Control

**生成量の主たる歯止めは LLM API のコストとする。**

```text
LLM呼び出し
↓
llm_usage へ記録（tokens / model / operation_type / cost）
↓
月次集計
↓
予算判定
```

### 予算配分

```text
観測・維持（固定費）  Sensors取り込み・抽出・Staleness評価
                      常時動作し、停止しない

生成（変動費）        残予算で実行
                      優先順位: Verification → Update → Create
```

観測を停止すると Stale Fact が検出されなくなり、
古い情報が公開され続けるため、観測は最優先で維持する。

### 予算超過時

```text
budget_action = degrade（既定）
```

停止せず、小さいモデルへ切り替えて継続する。

**degrade しても Content Grounding Engine（§19）は省略しない。**
文章品質は落としてよいが、根拠検証は落とさない。

## 39. Search / Vector Strategy

Embedding用途:

- Evidence Search
- Similar Content Detection
- Entity Candidate Matching
- Question Clustering

Truth判定をEmbeddingだけに依存しない。

pgvectorはOptionalにする。

## 40. Deployment Principle

> **PaaS-first, Docker-portable.**

Core must run with:

```text
1 application image
1 PostgreSQL database
1 LLM API
```

Workers / Schedulersは同じApplication Imageを使う。

## 41. PaaS Target

グローバルで一般的なPaaSを想定する。

Primary:

```text
Render
Railway
Heroku
Fly.io
```

Fallback:

```text
Generic Docker
```

## 42. Minimal PaaS Shape

```text
GitHub
  ↓
PaaS
├── Web        （管理UI）
├── Public     （生成ページ配信）
├── Worker
└── Scheduler
      ↓
Managed PostgreSQL

+
External APIs
├── LLM
└── Input Sources（Slack / Notion / SNS / WordPress ...）
```

公開ページ配信は同一イメージの別プロセスとして分離し、
管理UIとトラフィックを相互に干渉させない。

```text
1 deployment = 1 customer = 1 site
単一ドメインで配信する
```

## 43. Stateful Components

**PostgreSQLを唯一の必須Stateful Componentにする。**

初期から必須にしない:

```text
Redis
Elasticsearch
Neo4j
Kafka
Dedicated Vector DB
Persistent Disk
Kubernetes
```

## 44. Job Queue

Redisを必須にしない。

Railsなら:

```text
Solid Queue
```

等、PostgreSQLだけで完結する方式を優先する。

## 45. Filesystem

PaaSのLocal Filesystemを永続ストレージとして信用しない。

Phase 1:

```text
Database → PaaS PostgreSQL
Media → Existing WordPress Media Library
```

Later:

```text
Object Storage
```

をOptional追加。

## 46. One Image, Multiple Processes

同一Docker Imageを使う。

```text
Web:
  command: web        # 管理UI

Public:
  command: public     # 生成ページ配信

Worker:
  command: worker

Scheduler:
  command: scheduler
```

公開ページ配信を分離することで、
エンドユーザーのトラフィックが管理UIに影響しない。

PaaS固有コードをApplicationへ埋め込まない。

## 47. Environment Configuration

Deploy直後は最低限:

```text
DATABASE_URL
LLM_API_KEY
APP_SECRET
```

程度で起動できることを目標とする。

WordPress / GSC / GA4 / SlackはUIから接続可能にする。

## 48. Setup UX

**人間の操作を必須とするのは初期設定のみ。**

```text
Deploy to PaaS
↓
Open App
↓
Create Admin
↓
Q1: あなたの役割は？        ← 唯一の固定質問
↓
役割に応じた適応的ヒアリング
↓
入力源の接続（任意）
↓
運用開始
```

### 適応的ヒアリング

1問目で役割を検出し、以降の質問・用語・既定値を切り替える。

```text
専門家   → 専門用語で聞く。Policy編集権を開放
事業者   → 「お店のことを教えてください」
個人     → 「何について書きたいですか」
```

ヒアリング結果は goals / strategies / policies / site_policies へ構造化して保存する。
対話ログ自体は Evidence / Knowledge に入れない（意図と事実を混ぜない）。

Goal の数値化（metric / target_value / target_date）はシステム側が行い、
利用者に数値目標の設定を要求しない。

ユーザーに Ontology / Entity Schema / Agent設定を要求しない。

### 初回動作

```text
入力源あり → 取り込みから開始
入力源なし → ヒアリング内容のみで記事を1本生成
```

## 49. Recommended Phase 1 Stack

一例:

```text
Rails
PostgreSQL
Solid Queue
optional pgvector
LLM APIs
WordPress REST API
Google Search Console API
GA4 API
Slack API
Docker
```

## 50. Application Shape

初期はMicroservices化しない。

> **Modular Monolith**

Bounded Context:

```text
Ingestion
Knowledge
Search Intelligence
Content
Automation
Policy
Evaluation
```

## 51. Observability

最低限:

```text
Job status
LLM usage
Tool calls
Policy denials
Action errors
Extraction failures
Rollback events
Connector health
```

## 52. Security

```text
Tenant isolation
Secrets management
Audit log
Role-based permissions
Tool allowlists
Rate limits
Prompt injection isolation
```

## 53. Final Architecture Principle

> **Brainは高度でも、Deploymentは普通のWebアプリであるべき。**

そして、

> **LLMは賢さを提供するが、権限・真実・状態・ルールはLLMの外側に置く。**
