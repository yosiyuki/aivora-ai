# CMS as AI — Product Requirements & Phase 1 MVP

**Version:** 2.0  
**Scope:** Phase 1 — AI Publishing System

## 1. Product Vision

CMS as AIは、既存CMSにAI生成機能を追加するものではない。

目指すのは、

> **サイトのKnowledgeを理解し、正確性・鮮度・構造・検索機会を継続的に管理するAIシステム**

である。

そして CMS as AI は、

> **それ自身が出力CMSとして、ページを生成し配信する**

Phase 1 から既存CMSの代替として動作する。WordPress等は Source of Truth ではなく、
任意の入力源の1つである。

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
- **利用者に専門知識を要求しない**

## 3. Phase 1 Product Definition

Phase 1は **AI Publishing System** として定義する。

利用者から目的をヒアリングし、

- 目的を理解する
- 利用可能な入力源からKnowledgeを抽出する
- 不足しているFactを人間へ問い合わせる
- 根拠のあるページを生成する
- 生成したページを自ら配信する
- 古いFactを発見し更新する
- 重複・カニバリを発見する
- 不要な生成を抑制する
- コスト内で運用を継続する

ことを行う。

**人間の操作は初期設定のみを必須とする。**

## 4. Core User Value

ユーザーが得る価値:

- 専門知識がなくても、根拠のあるサイトを持てる
- 目的を伝えるだけで運用が始まる
- 古い情報が自動で発見・更新される
- AI生成文章の根拠を追跡できる
- 事実が不明な箇所は推測で埋められず、確認を依頼される
- 予算の範囲内で自動的に運用が続く
- サイト全体のKnowledge Healthを継続管理

## 5. Primary Users

**専門技能を前提としない。**

主対象:

- 何かを発信したい個人
- 店舗・サービスを運営する事業者
- 情報発信の担当者だが専門ではない人

CMS運用・SEO・コンテンツマーケティングの専門家は主対象としない。
ただし専門家が利用する場合は、ヒアリングで役割を検出し、詳細な設定を開放する。

## 6. Phase 1 Sensors

すべて任意。入力源が1つも無くても運用を開始できる。

```text
Website（クロール）
Slack
Notion
SNS
WordPress
```

Next:

```text
Search Console
GA4
Obsidian
CRM
Support
```

**WordPress連携は必須要件ではなく、Optional機能として位置づける。**

## 7. Main Product Areas

```text
Setup
Knowledge Health
Verification
Content
Actions
Results
Cost
Policies
```

以下は運用期（データ蓄積後）に開く:

```text
Opportunities
Suppressions
Search Health
Technical Health
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

**Knowledge Health は入力源が無くても機能する数少ない指標であり、
立ち上げ期の主指標とする。**

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

低Confidenceの場合は保留し、Verification Requestで確認する。

## 13. Fact Lifecycle

Factには以下を持たせる。

```text
valid_from
valid_until
last_verified_at
risk_level
confidence
```

特に以下をStaleness監視する。

- 価格
- 営業時間
- 運行情報
- 予約条件
- 所要時間

## 14. Verification Requests

Verification Request は2つの用途を持つ。

**(1) 再確認** — Stale Factや不確実なKnowledgeに対して

> Cafe Aの営業時間が8ヶ月確認されていません。現地確認してください。

**(2) 初回取得** — まだ存在しないFactに対して

> 記事にお店の営業時間を書きたいのですが、教えてください。

Slack / LINE / Email等を通じて人間へ確認を依頼し、返信をEvidenceへ戻す。

**(2) は立ち上げ期にKnowledgeを育てる主要な手段である。**
空のフォームにEntityとFactを入力させるのではなく、
生成されたページの空欄を埋める形で回答を得る。

## 15. Internal Knowledge Mining

Slack / Notion等から、

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

**本機能は運用期（GSC接続後）に有効化する。**

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

**本機能は運用期に有効化する。**

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

**すべてのDecisionは可逆でなければならない。**
PRUNE / MERGE は物理削除を伴わない（§23参照）。

## 19. Information Gain Gate

新規Content提案にはInformation Gain判定を行う。

評価対象:

- 一次情報
- 現地確認
- 独自写真 / 動画
- 独自測定
- 独自Experience
- 自社独自Knowledge

**ただし立ち上げ期には適用しない。**
Knowledgeが蓄積されていない段階で適用すると、何も出力できなくなるため。
利用者本人の体験・意見（Experiential Claim）は一次情報として扱う。

## 20. Claim Classification

生成される文章中のClaimを3種に分類し、扱いを変える。

```text
Verifiable Claim   検証可能な事実
                   「営業時間は9時から」「価格は500円」
                   → Knowledge必須。無ければ書かない

Experiential Claim 本人の体験・意見
                   「静かで落ち着ける」「初心者にもおすすめ」
                   → ヒアリング内容が出典

General Claim      一般常識
                   「コーヒーはカフェインを含む」
                   → 書けるが Fact として保存しない
```

**Verifiable Claim に根拠が無い場合、推測で埋めてはならない。**
該当箇所を空欄とし、Verification Requestを発行する。

## 21. Grounded Content

```text
Knowledge
 ↓
Draft
 ↓
Claim Extraction
 ↓
Claim Classification
 ↓
Knowledge Matching
 ↓
Grounding Check
```

Unsupported Claimは公開しない。

重要なのは、

> AIが自然に書けるか

ではなく、

> CMSがその文章の根拠を説明できるか

である。

**Human Reviewを必須としない設計であるため、
Grounding Checkが品質保証の中核となる。省略してはならない。**

## 22. Content Decay & Cannibalization

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

**Fact Staleness は即座に有効。その他はデータ蓄積後に有効化する。**

## 23. Deletion Policy

**物理削除を行わない。常に履歴を残す。**

```text
PRUNE  → 非公開化 + noindex + Campaign記録
         実体は削除しない

MERGE  → 統合先へ本文を追記
         統合元は noindex + canonical で統合先を指す
         統合元の本文は残す
```

理由:

- Human Reviewが無い設計では、不可逆な操作を系に持てない
- Campaign Rollbackがすべての変更を戻せる状態を維持する必要がある
- 削除の判断はサイト所有者の領分であり、自動化しない

## 24. Search World

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

**運用期に構築する。**

## 25. AI Search

Search VisibilityはGoogle Rankingだけに限定しない。

```text
Organic Search
AI Search
Search AI Features
Video Search
Other Discovery Channels
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

## 27. Setup / Onboarding

**人間の操作を必須とするのは初期設定のみ。**

```text
Deploy
 ↓
Create Admin
 ↓
Q1: あなたの役割は？          ← 唯一の固定質問
 ↓
役割に応じた適応的ヒアリング
 ↓
入力源の接続（任意）
 ↓
運用開始
```

### 適応的ヒアリング

1問目で利用者の役割を検出し、以降の質問を変える。

```text
専門家     → 専門用語で聞く。Policy編集権を開放
事業者     → 「お店のことを教えてください」から入る
個人       → 「何について書きたいですか」のみ
```

**必須なのは「目的」であり、Fact / Knowledge は任意とする。**

利用者に Ontology / Entity Schema / Agent設定を要求しない。
Goal の数値化（metric / target_value / target_date）はシステム側が行う。

対話ログそのものをEvidence / Knowledgeに入れない。
意図と事実を混ぜないため。

### 初回動作

```text
入力源あり → 取り込みから開始
入力源なし → ヒアリング内容のみで記事を1本生成
```

生成した記事の空欄をVerification Requestで埋め、Knowledgeを育てる。

## 28. Feasibility Check

CMSは達成不能なGoalを拒否または修正提案できる。

> **目標を突き返せるAI**

を設計原則とする。

**運用期に有効化する。** 新規サイトに適用すると、
ほぼすべての目標に「達成困難」と返すことになり、機能しないため。

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

**禁止条項は製品が固定値として持ち、利用者に設定させない。**

AIはヒアリング内容から制約を**追加**できるが、
製品固定の禁止条項を**緩和することはできない**。

理由: LLMの出力を縛る枠を同じLLMに決めさせると、枠の意味が失われるため。

## 30. Earned Autonomy

```text
Level 0 — Observe
Level 1 — Recommend
Level 2 — Draft
Level 3 — Low-risk Auto
Level 4 — Policy-bounded Autonomous
```

**Phase 1では初期設定で方針を一度与え、以降はPolicy Engineが機械的に適用する。**

個別Actionごとの人間承認は行わない。
不可逆な操作を系から排除している（§23）ため、Level 4でも回復可能性を維持できる。

## 31. Aggregate Policy

```text
max_new_pages_per_week
max_pages_changed_per_day
max_site_change_ratio
max_redirects_per_batch
max_links_changed_per_day
```

1件は安全でも大量なら危険、を制御する。

**Human Reviewが無い設計では、Aggregate Policy と Emergency Stop が
唯一の安全装置となる。既定値は保守的に置く。**

## 32. Cost Control

**生成量の主たる歯止めは LLM API のコストとする。**

### 予算配分

```text
観測・維持（固定費）  常時動く。停止しない
生成（変動費）        残りで実行する
```

優先順位:

```text
1. Verification（既存の正確性）
2. Update（既存の改善）
3. Create（新規作成）
```

### 利用者への提示

金額ではなく成果に翻訳して提示する。

```text
「月$50なら、記事を月3〜5本作れます」
「今月は$32使いました（記事4本）」
「Slackを繋ぐと精度が上がりますが、月$8ほど増えます」
```

素人利用者に使用量を予測させない。
製品が保守的な既定値を持ち、実績に基づいて調整を提案する。

### 予算超過時

```text
budget_action = degrade（既定）
```

停止せず、小さいモデルに切り替えて運用を継続する。

**degradeしてもGrounding Check（§21）は省略しない。**
文章の質は落としてよいが、根拠の検証は落とさない。

## 33. Emergency Stop

以下でAutomationをFreeze可能にする。

```text
Large traffic drop
Mass 404
Index anomaly
Redirect spike
Manual action
Large ranking loss
```

Campaign単位Rollbackに対応する。

## 34. Evaluation

最低限:

```text
Knowledge Extraction Accuracy
Entity Resolution Accuracy
Fact / Claim Classification Accuracy
Groundedness
Unsupported Claim Rate
Human Edit Rate
Action Rejection Rate
Rollback Rate
```

## 35. Primary Product KPI

重視するのは記事生成数ではなく、

```text
Verification Completion Rate
Stale Fact Reduction
Knowledge Health
Unsupported Claim Rate
Rollback Rate
Cost per Published Page
```

運用期に追加:

```text
Proposal Acceptance Rate
Cannibalization Resolution
```

## 36. Progressive Activation

立ち上げ期と運用期は**モードの切り替えではなく、機能ごとの段階的有効化**とする。

```text
Knowledge Health          → 即座に有効
Content生成               → 即座に有効
Verification              → Fact発生後
Fact Staleness            → Fact発生後
Content Decay             → トラフィックデータ蓄積後
Cannibalization           → ランキングデータ蓄積後
Opportunity / Feasibility → GSC接続後
Technical SEO             → 運用期
```

各機能は自身の前提データの有無を判定し、自律的に有効化する。
`mode` のような状態変数を持たない。

**立ち上げ期はできるだけ短くし、初期設定の延長として扱う。**

## 37. Deployment / Installation Principle

> **PaaS-first, Docker-portable**

Coreは以下だけで起動できることを目標とする。

```text
1 application image
1 PostgreSQL database
1 LLM API
```

External integrationsはOptional。

```text
1 deployment = 1 customer = 1 site
```

配信は単一ドメインで行う。サブドメイン発行の仕組みを持たない。
中央DNS・中央インフラを必要としない。

## 38. Phase 1 Success Condition

> 専門知識を持たない利用者が、目的を伝えるだけで、
> 根拠のあるサイトを立ち上げ、予算内で継続的に維持・成長させられること。

## 39. Product Positioning

Phase 1:

> **目的を伝えるだけで、根拠のあるサイトを作り、維持するAI**

最終思想:

> **サイトのKnowledgeを自律的に維持・成長させるAIシステム**
