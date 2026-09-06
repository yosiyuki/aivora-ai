# CMS as AI — Product Requirements & Phase 1 MVP

**Version:** 1.0  
**Scope:** Phase 1 — Shadow Brain / AI Media Operator

## 1. Product Vision

CMS as AIは、既存CMSにAI生成機能を追加するものではない。

目指すのは、

> **サイトのKnowledgeを理解し、正確性・鮮度・構造・検索機会を継続的に管理するAIシステム**

である。

最終ビジョンは、

> **CMSそのものがAIとして振る舞うこと**

だが、Phase 1では既存CMSを置き換えない。

## 2. Core Philosophy

従来のCMS:

```text
Human
  ↓
CMS
  ↓
Page
```

CMS as AI:

```text
Goal
 ↓
CMS as AI
 ↓
Observe
Understand
Decide
Plan
Act
Verify
Evaluate
Remember
```

重要な原則:

- **Page is not the source of truth. Knowledge is the source of truth.**
- **Content ≠ Page**
- **Content = Knowledge**
- **Page = Projection / Representation of Knowledge**
- **生成より判断を自動化する**
- **AIが知っていることと推測していることを混ぜない**
- **CMSを操作するのではなく、CMSに目的を与える**

## 3. Phase 1 Product Definition

Phase 1は **AI Media Operator** として定義する。

WordPress等の既存CMSをSource of Truthとして維持しながら、

- サイトを理解する
- Knowledgeを抽出する
- 古いFactを発見する
- 重複・カニバリを発見する
- 検索機会を発見する
- 不要な生成を抑制する
- 人間へVerification Requestを発行する
- 改善案を作る
- 根拠付き更新案を生成する
- Human Reviewを通して変更する

ことを行う。

## 4. Core User Value

ユーザーが得る価値:

- 古い情報を自動発見
- SEO上の重複・カニバリ検出
- GSC / GA4 / 社内Knowledge横断で機会発見
- Slack等に眠る知識をOwned Mediaへ活用
- Factの再確認をAIが人間へ依頼
- 新規作成だけでなくUpdate / Merge / Prune / Do Nothingを判断
- AI生成文章の根拠を追跡
- サイト全体のKnowledge Healthを継続管理

## 5. Primary Users

- Owned Media運営者
- SEO担当者
- Content Marketing担当者
- Web担当者
- Media Manager
- 複数サイトを運営するAgency / Company

## 6. Phase 1 Sensors

Required / First Class:

```text
WordPress
Search Console
GA4
Slack
```

Next:

```text
Notion
Obsidian
CRM
Support
Google Trends
YouTube
```

Later:

```text
TikTok
Instagram
Other external social signals
```

SNS監視はAPI制約・ToS・保守コストが大きいためPhase 1必須条件としない。

## 7. Main Product Areas

```text
Mission
Knowledge Health
Opportunities
Suppressions
Verification
Content Health
Search Health
Technical Health
Actions
Results
Policies
```

## 8. Knowledge Health

CMSは以下を監視する。

```text
Fresh Facts
Stale Facts
Conflicting Facts
Unverified Claims
Missing Evidence
Verification Requests
```

例:

```text
Knowledge Health: 87%

32 stale facts
8 conflicting facts
17 unverified claims
12 verification requests
```

## 9. Hybrid Knowledge

完全Knowledge Graph化を目的にしない。

```text
Knowledge
├── Structured
│   ├── Entity
│   ├── Fact
│   └── Relationship
│
└── Unstructured / Semi-structured
    ├── Evidence
    ├── Observation
    ├── Question
    ├── Problem
    ├── Experience
    └── Claim
```

価格、営業時間、住所、所要時間等の「間違うと実害がある情報」を優先的に構造化する。

## 10. Source → Evidence → Knowledge

```text
Source
 ↓
Raw Item
 ↓
Evidence / Signal
 ↓
Candidate Knowledge
 ↓
Validation
 ↓
Knowledge
```

LLMが抽出しただけではFactに昇格しない。

## 11. Knowledge Provenance

Knowledgeには可能な限り以下を持たせる。

```text
source
confidence
last_verified
```

KnowledgeとEvidenceの関係を保持し、

> この情報は何を根拠にしているか

を追跡できるようにする。

## 12. Entity Resolution

以下のような別名をCanonical Entityへ解決する。

```text
Cafe ABC
ABC Coffee
ABC Nguyễn Huệ
```

低Confidenceの場合はHuman Reviewへ。

## 13. Fact Lifecycle

Factには以下を持たせる。

```text
valid_from
valid_until
last_verified_at
risk_level
confidence
```

旅行領域では特に、

- 価格
- 営業時間
- 運行情報
- 予約条件
- 所要時間

をStaleness監視する。

## 14. Verification Requests

Stale Factや不確実なKnowledgeに対して、

```text
Verification Request
```

を発行する。

例:

> Cafe Aの営業時間が8ヶ月確認されていません。現地確認してください。

Slack / LINE / Email等を通じて人間へ確認を依頼し、返信をEvidenceへ戻す。

## 15. Internal Knowledge Mining

Slack等から、

```text
Observation
Question
Problem
Experience
```

を抽出する。

Raw Slackの文章を直接公開しない。

## 16. Opportunity Engine

以下を組み合わせて機会を発見する。

```text
Internal Knowledge
Search Demand
GSC
GA4
Audience Questions
Content Gaps
Business Value
SERP
Freshness
```

Opportunity Scoreはコードで計算し、LLMには出させない。

## 17. Suppression Engine

Opportunity Engineと同格で、

> **何をやるべきではないか**

を判断する。

抑制要因:

- Cannibalization
- Low Information Gain
- Low win probability
- Insufficient Evidence
- Excessive publishing / change rate
- Duplicate intent
- Quality risk

## 18. Possible Decisions

```text
KEEP
VERIFY
UPDATE
MERGE
PRUNE
NOINDEX
REDIRECT
RESTRUCTURE
LINK
CREATE
DO NOTHING
```

Createだけを成功Actionにしない。

## 19. Information Gain Gate

新規Content提案にはInformation Gain判定を必須とする。

評価対象:

- 一次情報
- 現地確認
- 独自写真 / 動画
- 独自測定
- 独自Experience
- SERP上位にないFact
- 自社独自Knowledge

不足する場合:

```text
REJECT_NEW_CONTENT
```

## 20. Content Decay & Cannibalization

既存Contentについて、

```text
Traffic Decay
Ranking Decay
CTR Decay
Fact Staleness
Broken Links
Query Overlap
```

を監視する。

必要に応じてUpdate / Merge / Redirect / Noindexを提案する。

## 21. Grounded Content

```text
Knowledge
 ↓
Draft
 ↓
Claim Extraction
 ↓
Knowledge Matching
 ↓
Grounding Check
```

Unsupported ClaimはReview対象。

重要なのは、

> AIが自然に書けるか

ではなく、

> CMSがその文章の根拠を説明できるか

である。

## 22. Search World

World Modelに以下を含める。

```text
queries
query_clusters
search_intents
serp_snapshots
competitor_pages
rankings
search_visibility
```

SEOはDemandだけでなく、Difficulty / Win Angle / Information Gainも考える。

## 23. Query Fan-out / Topic Coverage

Entity / Fact / Question / Problemを使い、

```text
Query Cluster Coverage
```

を把握する。

単一Keywordではなく、Topic全体でKnowledge Gapを検出する。

## 24. AI Search

Search VisibilityはGoogle Rankingだけに限定しない。

```text
Organic Search
AI Search
Search AI Features
Video Search
Other Discovery Channels
```

将来的にcitation_checks / visibility_checksを追加可能にする。

## 25. Technical SEO

Phase 1から以下を監視・提案対象にする。

```text
Canonical
Redirect
hreflang
Sitemap
Schema
Index Status
Broken Links
Internal Link Graph
```

## 26. Content Graph

Knowledge GraphとContent Graphを分ける。

```text
Knowledge Graph
= 世界について何を知っているか

Content Graph
= KnowledgeをWeb上でどう配置しているか
```

内部リンクはAnchor Diversity / Link Depth / Orphan Pages / Topic Clusterを考慮する。

## 27. Goal Driven Operation

```text
Goal
 ↓
Feasibility Check
 ↓
Human Strategy
 ↓
AI Planning
 ↓
Actions
```

AIにGoalだけを渡して完全自律させない。

## 28. Feasibility Check

CMSは達成不能なGoalを拒否または修正提案できる。

> **目標を突き返せるAI**

を設計原則とする。

## 29. Policy

### Operational Policy

```text
Can edit
Can publish
Can delete
Can redirect
Can noindex
Can change price
```

### Editorial Policy

```text
No unsupported claims
No exaggerated claims
No fake experience
Reader benefit first
Brand tone
No low-value SEO pages
```

## 30. Earned Autonomy

```text
Level 0 — Observe
Level 1 — Recommend
Level 2 — Draft
Level 3 — Low-risk Auto
Level 4 — Policy-bounded Autonomous
```

Site × Capability単位で設定する。

## 31. Aggregate Policy

```text
max_new_pages_per_week
max_pages_changed_per_day
max_site_change_ratio
max_redirects_per_batch
max_links_changed_per_day
```

1件は安全でも大量なら危険、を制御する。

## 32. Emergency Stop

以下でAutomationをFreeze可能にする。

```text
Large traffic drop
Mass 404
Index anomaly
Redirect spike
Manual action
Large ranking loss
```

Campaign単位Rollbackも将来的に対応する。

## 33. Evaluation

最低限:

```text
Knowledge Extraction Accuracy
Entity Resolution Accuracy
Fact / Claim Classification Accuracy
Groundedness
Unsupported Claim Rate
Opportunity Acceptance Rate
Human Edit Rate
Action Rejection Rate
Rollback Rate
```

## 34. Primary Product KPI

重視するのは記事生成数ではなく、

```text
Proposal Acceptance Rate
Human Edit Rate
Verification Completion Rate
Stale Fact Reduction
Cannibalization Resolution
Rollback Rate
```

## 35. Deployment / Installation Principle

Productとして、

> **PaaS-first, Docker-portable**

を採用する。

Coreは以下だけで起動できることを目標とする。

```text
1 application image
1 PostgreSQL database
1 LLM API
```

External integrationsはOptional。

理想の初期体験:

```text
Deploy
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

## 36. Phase 1 Success Condition

> CMSが既存サイトを理解し、人間より高頻度で問題・機会・古いKnowledgeを発見し、信頼できる改善提案を継続的に出せること。

## 37. Product Positioning

Phase 1:

> **サイトを理解し、維持し、育てるAI Media Operator**

最終思想:

> **サイトのKnowledgeを自律的に維持・成長させるAIシステム**
