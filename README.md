# aivora-ai - CMS as AI

## Product Requirements & Phase 1 MVP

**Version:** 0.9  
**Scope:** Phase 1 — Shadow Brain / AI Media Operator

---

# 1. Product Vision

CMS as AIは、既存CMSにAI生成機能を追加するものではない。

目指すのは、

> **サイトのKnowledgeを理解し、正確性・鮮度・構造・検索機会を継続的に管理するAI CMS**

である。

最終ビジョンは、

> **CMSそのものがAIとして振る舞うこと**

だが、Phase 1では既存CMSを置き換えない。

---

# 2. Phase 1 Product Definition

Phase 1のプロダクトは、

> **AI Media Operator**

として定義する。

WordPress等の既存CMSをSource of Truthとして維持しながら、

- サイトを理解する
- Knowledgeを抽出する
- 古い情報を発見する
- 重複・カニバリを発見する
- 検索機会を発見する
- 不要な生成を抑制する
- 人間へ確認を依頼する
- 改善案を作る
- 根拠付きの更新案を生成する

ことを行う。

---

# 3. Phase 1 Core Principle

Phase 1では、

```text
WordPress
    ↓
CMS as AI
```

の一方向同期とする。

CMS as AIからWordPressへの変更は、原則としてHuman Reviewを通す。

双方向同期は行わない。

---

# 4. Core User Value

ユーザーが得る価値は、

- サイト内の古い情報を自動発見できる
- SEO上の重複・カニバリを発見できる
- Search Console / GA4 / 社内Knowledgeを横断して機会を発見できる
- Slackに眠るユーザー課題をオウンドメディアへ活用できる
- 人間が忘れているFactの再確認をAIが依頼できる
- 記事を増やすだけでなく、更新・統合・削除候補を判断できる
- AI生成文章の根拠を追跡できる

ことである。

---

# 5. Primary Users

Phase 1の主対象は、

- オウンドメディア運営者
- SEO担当者
- コンテンツマーケティング担当者
- メディア責任者
- Web担当者
- 複数サイトを管理する事業者

とする。

---

# 6. Phase 1 Sensors

初期Sensorは以下に限定する。

```text
WordPress
Search Console
GA4
Slack
```

次候補：

```text
Notion
Obsidian
CRM
Support
Google Trends
YouTube
```

TikTok / Instagram等の外部SNS監視はPhase 1必須要件としない。

---

# 7. Main Product Areas

Phase 1ではUIを以下の領域で構成する。

```text
Mission
Knowledge Health
Opportunities
Suppressions
Verification
Content Health
Search Health
Actions
Results
Policies
```

---

# 8. Knowledge Health

CMSはサイトKnowledgeの状態を監視する。

主な指標：

```text
Fresh Facts
Stale Facts
Conflicting Facts
Unverified Claims
Missing Evidence
Verification Requests
```

例：

```text
Knowledge Health: 87%

32 stale facts
8 conflicting facts
17 unverified claims
12 verification requests
```

---

# 9. Existing Website Understanding

WordPressから、

- Posts
- Pages
- Categories
- Tags
- URLs
- Metadata
- Internal Links
- Media
- Structured Data

を取得する。

AIはサイト全体について、

- 何を扱っているか
- 主要Entity
- Audience
- Topic Cluster
- Search Intent
- Knowledge Coverage

をモデル化する。

---

# 10. Hybrid Knowledge Extraction

すべての文章をKnowledge Graph化しない。

構造化対象：

```text
Entity
Fact
Relationship
```

非構造・半構造対象：

```text
Evidence
Observation
Question
Problem
Experience
Claim
```

価格、営業時間、住所など、誤りの実害が大きい情報を優先的に構造化する。

---

# 11. Knowledge Provenance

Knowledgeには必ず可能な限り、

```text
source
confidence
last_verified
```

を保持する。

KnowledgeとEvidenceの関係を保持し、

> この情報は何を根拠にしているか

を追跡できるようにする。

---

# 12. Entity Resolution

Phase 1からEntity Resolutionを独立機能として実装する。

例：

```text
Cafe ABC
ABC Coffee
ABC Nguyễn Huệ
```

などが同一Entityかを判断する。

低Confidenceの場合は人間に統合候補として提示する。

---

# 13. Fact Staleness Detection

Factには、

```text
valid_from
valid_until
last_verified_at
risk_level
```

を持たせる。

一定期間確認されていないFactをStaleとして検出する。

特に対象：

- 価格
- 営業時間
- 所要時間
- 店舗状態
- 予約条件
- 運行情報

---

# 14. Verification Requests

Stale Factや不確実なKnowledgeに対して、

```text
Verification Request
```

を発行する。

例：

> Cafe Aの営業時間が8ヶ月確認されていません。現地確認してください。

Slack等へ通知し、返信をEvidenceとして取り込む。

---

# 15. Slack Knowledge Mining

Slackの会話から、

```text
Observation
Question
Problem
Experience
```

を抽出する。

例：

```text
「最近Grabの乗り場を聞かれることが増えた」
```

↓

```text
Observation:
Grab乗車場所への質問増加
```

Slack本文そのものを直接公開しない。

---

# 16. Opportunity Detection

CMSは、

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

から機会を発見する。

Opportunity Scoreはコードで計算し、LLMには生成させない。

---

# 17. Suppression Engine

Opportunity Engineと同格で、

```text
Suppression Engine
```

を持つ。

判断対象：

- 既存記事とカニバリする
- SERPで勝ち目がない
- Information Gainがない
- 類似記事が多い
- サイト変更量が多すぎる
- 独自Evidenceがない

場合は、

```text
DO NOT CREATE
```

を判断できる。

---

# 18. Possible Decisions

CMSが出せる判断は、

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

とする。

Createを唯一の成功Actionにしない。

---

# 19. Information Gain Gate

新規記事提案には必ずInformation Gain判定を行う。

評価対象：

- 一次情報
- 実体験
- 独自写真
- 独自測定
- 既存SERPにないFact
- 自社独自Knowledge
- 現地スタッフ確認

Information Gainが不足する場合は、新規記事作成を抑制する。

---

# 20. Content Decay Detection

既存記事について、

```text
Traffic Decay
Ranking Decay
CTR Decay
Stale Facts
Broken Links
```

を監視する。

新規記事生成より既存資産の改善を優先する。

---

# 21. Cannibalization Detection

同一または近似Search Intentについて複数URLが競合している場合、

```text
Cannibalization Candidate
```

として検出する。

AIは、

- Keep
- Merge
- Redirect
- Reposition

を提案する。

---

# 22. Pruning Recommendations

以下を検出する。

```text
Zero Traffic
No Backlinks
Duplicate Intent
Index Bloat
Expired Content
Broken Knowledge
```

削除・noindex・統合はHuman Approvalを必須とする。

---

# 23. Internal Link Recommendations

内部リンクを単純な関連度だけで提案しない。

以下を考慮する。

```text
Topic Cluster
Link Depth
Anchor Diversity
Inbound Distribution
Orphan Pages
Existing Link Density
```

Phase 1では基本的に提案のみとする。

---

# 24. Technical SEO Recommendations

Phase 1で検出・提案対象とする。

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

---

# 25. Grounded Content Update

既存記事の更新案を生成する場合、

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

を行う。

根拠のないClaimはReview対象とする。

---

# 26. Human Review

Phase 1では、

```text
AI Proposal
↓
Diff / Preview
↓
Human Review
↓
Publish
```

を基本とする。

---

# 27. Earned Autonomy

自動化は後から解放する。

```text
Level 0 — Observe
Level 1 — Recommend
Level 2 — Draft
Level 3 — Low-risk Auto
Level 4 — Policy-bounded Autonomous
```

Site × Capabilityごとに設定する。

---

# 28. Aggregate Policy

単一Actionだけでなく、サイト全体の変更量を制御する。

```text
max_new_pages_per_week
max_pages_changed_per_day
max_site_change_ratio
max_redirects_per_batch
max_links_changed_per_day
```

---

# 29. Emergency Stop

以下で自動ActionをFreezeできるようにする。

```text
Large traffic drop
Mass 404
Index anomaly
Redirect spike
Manual action
Large ranking loss
```

---

# 30. Phase 1 Eval

最低限以下を計測する。

```text
Knowledge Extraction Accuracy
Entity Resolution Accuracy
Fact / Claim Accuracy
Groundedness
Unsupported Claim Rate
Opportunity Acceptance Rate
Human Edit Rate
Action Rejection Rate
Rollback Rate
```

---

# 31. Primary Product KPI

AIが何記事書いたかではなく、

```text
Proposal Acceptance Rate
Human Edit Rate
Verification Completion Rate
Stale Fact Reduction
Content Decay Reduction
Cannibalization Resolution
Rollback Rate
```

を重視する。

---

# 32. What Phase 1 Does Not Do

Phase 1では以下を目標にしない。

```text
Full autonomous publishing
Full Knowledge Graph
Perfect ontology
Full social monitoring
Continuous AI learning
Mass article generation
Full multi-channel publishing
```

---

# 33. Phase 1 Success Condition

Phase 1が成功した状態は、

> CMSが既存サイトを理解し、人間より高頻度で問題・機会・古いKnowledgeを発見し、信頼できる改善提案を継続的に出せる

ことである。

---

# 34. Product Positioning

Phase 1では、

> **AIが記事を書くCMS**

ではなく、

> **サイトを理解し、維持し、育てるAI Media Operator**

として位置づける。

---

# 35. Product Philosophy

最も重要な原則：

> **生成より判断を自動化する。**

そして、

> **CMSを操作するのではなく、CMSに目的を与える。**
