# CMS as AI — Technical Architecture

**Version:** 1.0  
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

Phase 1:

```text
WordPress Connector
Search Console Connector
GA4 Connector
Slack Connector
```

Later:

```text
Notion
Obsidian
CRM
Support
Google Trends
YouTube
TikTok
Instagram
```

ConnectorsはPlugin的に追加可能にし、Coreと分離する。

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

## 22. WordPress Adapter

Phase 1:

```text
WordPress
↓
CMS as AI
```

Field Ownershipを明示する。

例:

```text
Body → WordPress
Canonical → SEO Plugin
Schema → CMS as AI
```

複数システムで同一Fieldを書かない。

## 23. Avoid Bidirectional Sync

設計原則:

```text
One domain
One canonical owner
```

Phase 1はWP→AI。  
将来AIがCanonicalになった場合はAI→WP。

無制限な双方向同期は避ける。

## 24. Planner

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

## 25. Feasibility Engine

```text
Search Demand
Reachable Ranking
Expected CTR
Expected Conversion
Time Horizon
```

等からGoal達成可能性を評価する。

## 26. Policy Engine

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

## 27. Tool Runtime

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

## 28. Tool Categories

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

## 29. Review System

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

Review結果はOperational Memoryへ保存する。

## 30. Earned Autonomy

Site × Capabilityで管理。

```text
Fact Verification → Level 4
Schema → Level 4
Internal Link → Level 2
Content Update → Level 1
Delete → Level 0
```

## 31. Aggregate Policy

```text
Site-wide Change Rate
Batch Size
Daily Action Count
Publishing Rate
Redirect Count
Link Change Count
```

を評価する。

## 32. Emergency Stop & Campaign Rollback

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

## 33. Memory

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

## 34. Evaluation Architecture

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

## 35. Background Processing

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

## 36. Model Routing

```text
Small Model
→ classification / extraction

Mid Model
→ entity resolution / summarization

Strong Model
→ planning / complex reasoning / drafting
```

## 37. Search / Vector Strategy

Embedding用途:

- Evidence Search
- Similar Content Detection
- Entity Candidate Matching
- Question Clustering

Truth判定をEmbeddingだけに依存しない。

pgvectorはOptionalにする。

## 38. Deployment Principle

> **PaaS-first, Docker-portable.**

Core must run with:

```text
1 application image
1 PostgreSQL database
1 LLM API
```

Workers / Schedulersは同じApplication Imageを使う。

## 39. PaaS Target

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

## 40. Minimal PaaS Shape

```text
GitHub
  ↓
PaaS
├── Web
├── Worker
└── Scheduler
      ↓
Managed PostgreSQL

+
External APIs
├── LLM
├── WordPress
├── GSC
├── GA4
└── Slack
```

## 41. Stateful Components

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

## 42. Job Queue

Redisを必須にしない。

Railsなら:

```text
Solid Queue
```

等、PostgreSQLだけで完結する方式を優先する。

## 43. Filesystem

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

## 44. One Image, Multiple Processes

同一Docker Imageを使う。

```text
Web:
  command: web

Worker:
  command: worker

Scheduler:
  command: scheduler
```

PaaS固有コードをApplicationへ埋め込まない。

## 45. Environment Configuration

Deploy直後は最低限:

```text
DATABASE_URL
LLM_API_KEY
APP_SECRET
```

程度で起動できることを目標とする。

WordPress / GSC / GA4 / SlackはUIから接続可能にする。

## 46. Setup UX

```text
Deploy to PaaS
↓
Open App
↓
Create Admin
↓
Enter Site URL
↓
Connect WordPress
↓
Select LLM Provider
↓
Start Scan
```

ユーザーに初期からOntology / Entity Schema / Agent設定を要求しない。

## 47. Recommended Phase 1 Stack

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

## 48. Application Shape

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

## 49. Observability

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

## 50. Security

```text
Tenant isolation
Secrets management
Audit log
Role-based permissions
Tool allowlists
Rate limits
Prompt injection isolation
```

## 51. Final Architecture Principle

> **Brainは高度でも、Deploymentは普通のWebアプリであるべき。**

そして、

> **LLMは賢さを提供するが、権限・真実・状態・ルールはLLMの外側に置く。**
