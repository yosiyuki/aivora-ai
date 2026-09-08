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
ヒアリング（§27.1）
 ↓
入力源の接続（任意）
 ↓
記事1本を生成・公開
 ↓
運用開始
```

### 27.1 ヒアリングの原則

**すべての質問を自由記述とする。選択肢を出さない。**

選択肢を提示すると、利用者は自分の言葉を捨ててこちらの語彙に合わせる。
その瞬間に情報が失われる。

```text
❌ □来てほしい □知ってほしい

✅ 「常連さんが増えなくて、新しい人にも来てほしい。
    でも観光客ばかりだと雰囲気が変わってしまう」
```

素人は専門用語を持たないだけで、情報を持っていないわけではない。
**自分の言葉なら詳しく語れる。**

さらに、自由記述の回答はそのまま Experiential Claim の原料となる（§20）。
選択肢の回答は記事に書けないが、本人の言葉は書ける。
**ヒアリングは設定行為であると同時に、最初のKnowledge収集である。**

### 27.2 例示の使い方

自由記述には**例を3つ**添える。選択肢ではなく、粒度の見本として。

```text
Q「何について発信しますか？」

  例:
  ・渋谷でカフェをやっています。自家焙煎の豆にこだわっていて…
  ・機械学習を独学していて、詰まったところをメモに残したい
  ・フリーランスでデザインをしています。実績を見てもらいたい
```

長さの異なる例を複数出すことで「自由に書いてよい」ことを伝え、
短文回答を防ぐ。

### 27.3 質問の構造

```text
Layer 1  判定    Archetypeを決めるための最小限
Layer 2  充足    最初の1本に必要なスロットを埋める
Layer 3  継続    Verification Request として非同期に継続
```

**初期設定で全スロットを埋めさせない。**
最初の記事1本に必要な分（minimum）のみを聞き、
残りは生成された記事の空欄として Verification Request に流す（§14）。

```text
required_slots の充足レベル

minimum    最初の1本に必要        → 初期設定で聞く
standard   サイトとして必要        → Verification Request
enriched   あると良い             → Verification Request
```

### 27.4 Archetype は聞かずに推論する

利用者に目的を選ばせない。**発言から抽出する。**

```text
「渋谷でカフェをやっています」
  → 実在店舗・場所性・事業者の一人称 → business

「詰まったところをメモに残したい」
  → 概念領域・継続的に増える・問題解決 → knowledge_base + media

「実績を見てもらいたい」
  → 「見てもらう」に目的が含まれる → portfolio
```

素人は目的を語らないのではなく、**目的を含んだ言い方をする**。
動詞に目的が現れるため、選ばせる必要がない。

判定できない場合のみ、1問だけ自由記述で確認する。
Archetype は後から追加でき、URLも変わらない（§28）ため、
初回判定の完璧さを求めない。

### 27.5 深掘りの順序

追加質問も自由記述とし、**相手の言葉を引用して聞く**。

```text
利用者「渋谷でカフェをやっています。豆にこだわってます」

  ✅ 「豆へのこだわり、もう少し聞かせてください」
  ❌ 「営業時間を入力してください」
```

相手が熱を持って語れる話題から入ると、
その後の事務的な質問にも答えてもらえる。逆順では離脱する。

### 27.6 発言の行き先

ヒアリング中の発言を種類ごとに分けて処理する（§20 Claim Classification）。

```text
意図の表明   「集客したい」          → goals
                                     Knowledgeにしない

事実の言明   「7時に開けています」    → Fact

体験の言明   「豆は農園から直接」      → Experience
                                     記事に書ける
```

**対話ログそのものをKnowledgeに入れない。**
意図と事実を混ぜないため。発言の種類を判定した上で振り分ける。

ヒアリング回答も外部入力であり、Extraction Agent が処理する。
Agent Isolation（Technical Architecture §7）に例外を作らない。

### 27.7 終了条件

進捗は見せるが、スロット名は見せない。

```text
❌ 「必須スロット 3/6 充足」
✅ 「あと少しで最初のページが作れます」
✅ 「もう十分です。ページを作ってみますか？」
```

minimum が充足した時点で生成可能を提示し、継続するかは利用者に委ねる。

**上限を設ける。** 10問程度で打ち切り、
「一度ページを作ってみましょう」と進める。
話が逸れた場合、その内容は Evidence として保存した上で、質問を本筋に戻す。

コストが読めなくなることを防ぐ意味も持つ（§33）。

### 27.8 役割による差

```text
変える:  語彙 / 質問数 / 例示の内容 / 深掘りの深さ
変えない: 必須スロット / Archetype判定ロジック
```

**必須スロットを役割で変えてはならない。**
「店の場所」は誰が運営していても必要である。
役割で変わるのは聞き方であって、必要な情報ではない。

### 27.9 その他

Goal の数値化（metric / target_value / target_date）はシステム側が行い、
利用者に数値目標の設定を要求しない。

利用者に Ontology / Entity Schema / Agent設定を要求しない。

### 27.10 初回動作

```text
入力源あり → 取り込みから開始
入力源なし → ヒアリング内容のみで記事を1本生成
```

生成した記事の空欄を Verification Request で埋め、Knowledge を育てる。

## 28. Site Structure / Archetype

**サイト構造は利用者が選ぶのではなく、目的から導出する。**

```text
Q1: 役割        → 語彙・深さ・Policy編集権
目的ヒアリング   → Archetype → 構造 + 必要Knowledgeスロット
```

利用者は Archetype という概念に触れない。
Ontology / Entity Schema を要求しないのと同じ理由による（§27）。

### Archetype

Archetype は見た目の分類ではなく、**Goal の構造的表現**である。

```text
目的                      metric        Archetype        構造

お店を知ってほしい          来店・問合せ   business        Top / サービス / FAQ / お知らせ
知見を発信したい            訪問・回遊     media           Top / 記事一覧 / カテゴリ / 記事
質問に答えたい              自己解決       knowledge_base  Top / トピック / Q&A
実績を見せたい              到達・連絡     portfolio       Top / 作品 / プロフィール
```

### 複合型

実際には複数の目的を持つ利用者が多いため、複合を許す。

```text
primary_archetype      business
secondary_archetypes   [media]
```

### Knowledge スロット

Archetype は必要とするKnowledgeスロットを定義する。
**スロットの優先度は、目的への貢献度で決まる。**

```text
business
  必須: 場所 / 営業時間 / 提供内容 / 連絡手段
  → 欠けていると目的を達成できないため、
    Verification Request の優先度が高い

media
  営業時間の欠落は目的に影響しないため、優先度は低い
```

Knowledge Health（§8）の算出も Archetype に依存する。

### 構造定義は製品が持つ

Archetype ごとの構造・必須スロット・優先度は**製品固定のマスタ**とする。
AIが行うのは「目的からどのArchetypeか」の判定のみであり、
構造そのものを発明させない。

理由は Editorial Policy を製品固定とするのと同じ（§29）。

### URL不変の規律

```text
一度発行したURLは変更しない
```

目的が変化して Archetype が追加されても、既存URLは動かさない。
構造は**足せるが動かさない**。

Knowledge の増減でページを消さない（§23 物理削除の禁止と一致）。
公開停止は status の変更で表現する。

**理由:** URLが動くと検索評価が積み上がらず、
Content Decay を検出すべきシステム自身が Decay を生むことになる。

## 29. Feasibility Check

CMSは達成不能なGoalを拒否または修正提案できる。

> **目標を突き返せるAI**

を設計原則とする。

**運用期に有効化する。** 新規サイトに適用すると、
ほぼすべての目標に「達成困難」と返すことになり、機能しないため。

## 30. Policy

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

## 31. Earned Autonomy

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

## 32. Aggregate Policy

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

## 33. Cost Control

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

## 34. Emergency Stop

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

## 35. Evaluation

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

## 36. Primary Product KPI

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

## 37. Progressive Activation

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

## 38. Deployment / Installation Principle

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

## 39. Phase 1 Success Condition

> 専門知識を持たない利用者が、目的を伝えるだけで、
> 根拠のあるサイトを立ち上げ、予算内で継続的に維持・成長させられること。

## 40. Product Positioning

Phase 1:

> **目的を伝えるだけで、根拠のあるサイトを作り、維持するAI**

最終思想:

> **サイトのKnowledgeを自律的に維持・成長させるAIシステム**
