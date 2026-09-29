module ContentFixtures
  # A site after a "渋谷でカフェ" interview: one business entity, one accepted
  # fact (location), two experiences, one goal. Returns the site.
  def cafe_site
    site = Site.current || create_site(name: "渋谷のカフェ", domain: "cafe.example")
    site.add_archetype(:business, primary: true) unless site.primary_archetype
    entity = site.primary_entity || site.entities.create!(entity_type: "business", canonical_name: "渋谷のカフェ").tap { |e| site.update!(primary_entity: e) }
    unless entity.facts.exists?(slot_key: "location")
      fact = entity.facts.create!(attribute_key: "場所", slot_key: "location", value_json: { "value" => "渋谷" }, confidence: 0.9)
      fact.accept!(evidence: owner_evidence(site, text: "渋谷でカフェをやっています"))
    end
    if site.experiences.none?
      # Slot-keyed, the way the router writes them: `story` feeds the profile
      # page, `what` feeds services and profile.
      site.experiences.create!(entity: entity, summary: "自家焙煎", body: "豆は農園から直接仕入れて自分で焙煎しています", person_id: "owner", slot_key: "story")
      site.experiences.create!(entity: entity, summary: "静かな店内", body: "一人でも長居しやすい静かな雰囲気にしています", person_id: "owner", slot_key: "what")
    end
    if site.questions.none?
      site.questions.create!(entity: entity, text: "駐車場はありますか").add_evidence!(owner_evidence(site, text: "駐車場はありますかとよく聞かれます"))
      site.questions.create!(entity: entity, text: "予約はできますか").add_evidence!(owner_evidence(site, text: "予約はできますかとよく聞かれます"))
    end
    site.goals.create!(name: "来てほしい", description: "近所の人にもっと来てほしい", metric: "visits_or_inquiries") if site.goals.none?
    site
  end

  def cafe_draft = <<~MD
    # 渋谷のカフェ

    渋谷にある小さなカフェです。豆は農園から直接仕入れて自分で焙煎しています。

    ## 店内について
    一人でも長居しやすい静かな雰囲気にしています。

    ## 営業時間・場所
    営業時間は [[slot:hours]] です。場所は渋谷です。
  MD

  def cafe_claims(pack)
    f = pack.facts.first.ref
    e1, e2 = pack.experiences.map(&:ref)
    [
      { "statement" => "渋谷にある小さなカフェです。", "kind" => "verifiable", "support" => { "ref" => f }, "slot_key" => nil, "confidence" => 0.9 },
      { "statement" => "豆は農園から直接仕入れて自分で焙煎しています。", "kind" => "experiential", "support" => { "ref" => e1 }, "slot_key" => nil, "confidence" => 0.9 },
      { "statement" => "一人でも長居しやすい静かな雰囲気にしています。", "kind" => "experiential", "support" => { "ref" => e2 }, "slot_key" => nil, "confidence" => 0.9 },
      { "statement" => "場所は渋谷です。", "kind" => "verifiable", "support" => { "ref" => f }, "slot_key" => "location", "confidence" => 0.95 },
      { "statement" => "## 店内について", "kind" => "general", "support" => nil, "slot_key" => nil, "confidence" => 0.9 },
      { "statement" => "## 営業時間・場所", "kind" => "general", "support" => nil, "slot_key" => nil, "confidence" => 0.9 }
    ]
  end

  # Stubs both calls for the top page. Pass page_type: to stub another page
  # type instead; each page's pack differs, so the claims are built against
  # the pack of the page being generated.
  def stub_generation(draft: nil, claims: nil, page_type: "top")
    draft ||= page_type == "faq" ? cafe_faq_draft : cafe_draft
    Llm::Fake.respond(:drafting) { draft }
    Llm::Fake.respond(:grounding) do |_call|
      pack = Content::KnowledgePack.for(Site.current, page_type: page_type)
      { "claims" => claims || (page_type == "faq" ? cafe_faq_claims(pack) : cafe_claims(pack)) }
    end
  end

  def cafe_faq_draft = <<~MD
    # よくある質問

    ## 駐車場はありますか
    場所は渋谷です。

    ## 予約はできますか
    一人でも長居しやすい静かな雰囲気にしています。
  MD

  def cafe_faq_claims(pack)
    f = pack.facts.first.ref
    q1, q2 = pack.questions.map(&:ref)
    e = pack.experiences.find { |x| x.summary == "静かな店内" }.ref
    [
      { "statement" => "## 駐車場はありますか", "kind" => "experiential", "support" => { "ref" => q1 }, "slot_key" => nil, "confidence" => 0.9 },
      { "statement" => "場所は渋谷です。", "kind" => "verifiable", "support" => { "ref" => f }, "slot_key" => "location", "confidence" => 0.95 },
      { "statement" => "## 予約はできますか", "kind" => "experiential", "support" => { "ref" => q2 }, "slot_key" => nil, "confidence" => 0.9 },
      { "statement" => "一人でも長居しやすい静かな雰囲気にしています。", "kind" => "experiential", "support" => { "ref" => e }, "slot_key" => nil, "confidence" => 0.9 }
    ]
  end
end

RSpec.configure { |c| c.include ContentFixtures }
