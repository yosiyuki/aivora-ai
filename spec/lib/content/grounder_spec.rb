require "rails_helper"

RSpec.describe Content::Grounder do
  let!(:site) { cafe_site }
  let(:pack) { Content::KnowledgePack.for(site, page_type: "top") }
  let(:grounder) { described_class.new(pack) }
  let(:f) { pack.facts.first.ref }
  let(:e1) { pack.experiences.first.ref }

  def claim(statement, kind:, ref: nil, slot_key: nil)
    { "statement" => statement, "kind" => kind, "support" => ref && { "ref" => ref }, "slot_key" => slot_key, "confidence" => 0.9 }
  end

  it "passes a fully covered, fully grounded draft and records claims with offsets", :aggregate_failures do
    body = cafe_draft.lines[2..].join
    claims = cafe_claims(pack) + [
      claim("## 店内について", kind: "general"), claim("## 営業時間・場所", kind: "general")
    ]
    result = grounder.ground(body: body, claims: claims)
    expect(result.status).to eq(:passed)
    expect(result.body).to include("場所は渋谷です。")
    grounded = result.claims.select { |c| c[:review_status] == "grounded" }
    expect(grounded.map { |c| c[:knowledge_type] }).to contain_exactly("Fact", "Experience", "Experience", "Fact")
    expect(grounded.first[:start_offset]).to be_a(Integer)
    expect(result.blanks).to include("slot_key" => "hours", "statement" => nil), "the drafter's own placeholder is a blank"
  end

  # --- fail-closed coverage ------------------------------------------------

  it "removes every sentence the extractor did not cover, and fails when nothing is left" do
    result = grounder.ground(body: "根拠のない24時間営業です。", claims: [])
    expect(result.status).to eq(:failed)
    expect(result.body).to be_blank
    expect(result.notes).to include(match(/uncovered/))
  end

  it "removes an uncovered sentence next to a covered one" do
    body = "渋谷にあるカフェです。実は24時間営業です。"
    result = grounder.ground(body: body, claims: [ claim("渋谷にあるカフェです。", kind: "verifiable", ref: f) ])
    expect(result.status).to eq(:passed)
    expect(result.body).to eq("渋谷にあるカフェです。")
  end

  it "keeps short label headings but fails on an uncovered heading with specifics" do
    ok = grounder.ground(body: "## どんなお店か\n渋谷にあるカフェです。", claims: [ claim("渋谷にあるカフェです。", kind: "verifiable", ref: f) ])
    expect(ok.status).to eq(:passed)
    expect(ok.body).to start_with("## どんなお店か")

    bad = grounder.ground(body: "## 24時間営業\n渋谷にあるカフェです。", claims: [ claim("渋谷にあるカフェです。", kind: "verifiable", ref: f) ])
    expect(bad.status).to eq(:failed)
  end

  it "treats a 'general' claim with numbers or shop-specific words as verifiable" do
    result = grounder.ground(body: "渋谷のカフェは24時間営業です。", claims: [ claim("渋谷のカフェは24時間営業です。", kind: "general") ])
    expect(result.status).to eq(:failed), "misclassified specifics do not slip through as general"
    expect(result.claims.sole[:claim_kind]).to eq("verifiable")
    expect(result.claims.sole[:review_status]).to eq("excised")
  end

  it "keeps genuinely general prose" do
    result = grounder.ground(body: "コーヒーにはカフェインが含まれます。", claims: [ claim("コーヒーにはカフェインが含まれます。", kind: "general") ])
    expect(result.body).to eq("コーヒーにはカフェインが含まれます。")
    expect(result.claims.sole).to include(review_status: "general", grounded: true, knowledge_type: nil)
  end

  # --- experiences: the owner's words, by text not by reference ----------------

  it "grounds a sentence in the owner's own words even when the model called it verifiable" do
    body = "コーヒーの豆は、農園から直接仕入れて、自分で焙煎しています。店内は、一人でも長居しやすい静かな雰囲気にしています。"
    claims = [ claim("コーヒーの豆は、農園から直接仕入れて、自分で焙煎しています。", kind: "verifiable", slot_key: "offerings"),
               claim("店内は、一人でも長居しやすい静かな雰囲気にしています。", kind: "verifiable") ]
    result = grounder.ground(body: body, claims: claims)
    expect(result.body).to eq(body)
    expect(result.claims.map { |c| c[:review_status] }).to eq(%w[grounded grounded])
    expect(result.claims.map { |c| c[:claim_kind] }).to eq(%w[experiential experiential])
  end

  it "does not trust an experience reference whose text does not match" do
    result = grounder.ground(body: "世界一のカフェです。", claims: [ claim("世界一のカフェです。", kind: "experiential", ref: e1) ])
    expect(result.body).to be_blank
    expect(result.status).to eq(:failed)
    expect(result.claims.sole[:review_status]).to eq("excised")
  end

  it "does not let a short owner phrase carry a long fabricated sentence" do
    site.experiences.create!(entity: site.primary_entity, summary: "静か", body: "静かな店", person_id: "owner")
    p2 = Content::KnowledgePack.for(site, page_type: "top")
    result = described_class.new(p2).ground(body: "静かな店で、24時間営業です。", claims: [ claim("静かな店で、24時間営業です。", kind: "experiential") ])
    expect(result.claims.sole[:review_status]).to eq("excised")
    expect(result.status).to eq(:failed)
  end

  it "excises an experiential sentence with no experience behind it" do
    body = "渋谷にあるカフェです。常連さんはみんな笑顔で帰ります。"
    result = grounder.ground(body: body, claims: [ claim("渋谷にあるカフェです。", kind: "verifiable", ref: f),
                                                    claim("常連さんはみんな笑顔で帰ります。", kind: "experiential") ])
    expect(result.body).to eq("渋谷にあるカフェです。")
    expect(result.claims.last).to include(review_status: "excised", grounded: false)
  end

  # --- facts: value, numbers, short values -------------------------------------

  it "removes a verifiable sentence with no fact behind it and leaves the slot in its place" do
    body = "渋谷にあるカフェです。営業時間は朝7時から夕方5時までです。豆は農園から直接仕入れて自分で焙煎しています。"
    claims = [ claim("渋谷にあるカフェです。", kind: "verifiable", ref: f),
               claim("営業時間は朝7時から夕方5時までです。", kind: "verifiable", ref: nil, slot_key: "hours"),
               claim("豆は農園から直接仕入れて自分で焙煎しています。", kind: "experiential", ref: e1) ]
    result = grounder.ground(body: body, claims: claims)
    expect(result.status).to eq(:passed)
    expect(result.body).to eq("渋谷にあるカフェです。[[slot:hours]]豆は農園から直接仕入れて自分で焙煎しています。")
    expect(result.claims.find { |c| c[:review_status] == "blank" }).to include(slot_key: "hours", grounded: false, knowledge_type: nil)
  end

  it "does not trust a fact reference whose value is not in the sentence" do
    result = grounder.ground(body: "新宿にあるカフェです。", claims: [ claim("新宿にあるカフェです。", kind: "verifiable", ref: f) ])
    expect(result.body).to eq("[[slot:location]]")
    expect(result.claims.sole[:review_status]).to eq("blank")
  end

  it "rejects a sentence that adds numbers the pack does not know, even with a matching fact" do
    result = grounder.ground(body: "渋谷で24時間営業しています。", claims: [ claim("渋谷で24時間営業しています。", kind: "verifiable", ref: f) ])
    expect(result.claims.sole[:review_status]).to eq("blank")
    expect(result.body).to eq("[[slot:location]]")
  end

  it "grounds a short numeric value only alongside its slot label" do
    fact = site.primary_entity.facts.create!(attribute_key: "hours", value_json: { "value" => "7" }, confidence: 0.9)
    fact.accept!(evidence: owner_evidence(site, text: "7時から"))
    p2 = Content::KnowledgePack.for(site, page_type: "top")
    ref = p2.facts.find { |x| x.attribute_key == "hours" }.ref
    g = described_class.new(p2)

    expect(g.ground(body: "週7日開いています。", claims: [ claim("週7日開いています。", kind: "verifiable", ref: ref) ]).claims.sole[:review_status]).to eq("blank")
    expect(g.ground(body: "営業時間は7です。", claims: [ claim("営業時間は7です。", kind: "verifiable", ref: ref) ]).claims.sole[:review_status]).to eq("grounded")
  end

  # --- placeholders --------------------------------------------------------

  it "drops a whole line carrying an unknown placeholder key and collapses repeats" do
    result = grounder.ground(body: "駐車場は [[slot:parking]] です。\n営業時間: [[slot:hours]] と [[slot:hours]]", claims: [])
    expect(result.body).to eq("営業時間: [[slot:hours]] と")
    expect(result.blanks.map { |b| b["slot_key"] }).to eq([ "hours" ])
    expect(result.status).to eq(:passed)
  end

  it "fails when a placeholder sits in a heading" do
    result = grounder.ground(body: "## [[slot:hours]]\n渋谷にあるカフェです。", claims: [ claim("渋谷にあるカフェです。", kind: "verifiable", ref: f) ])
    expect(result.status).to eq(:failed)
  end

  it "keeps placeholder sentences with plain framing and removes ones that smuggle specifics" do
    body = "行き方の詳細は [[slot:access]] をご確認ください。\n駅から3分、詳しくは [[slot:access]] へ。"
    result = grounder.ground(body: body, claims: [])
    expect(result.body).to eq("行き方の詳細は [[slot:access]] をご確認ください。")
    expect(result.status).to eq(:passed)
  end

  it "drops a heading whose section was entirely removed, and horizontal rules" do
    body = "## 店内の過ごし方\n常連さんはみんな笑顔で帰ります。\n\n---\n\n## 場所\n渋谷にあります。"
    result = grounder.ground(body: body, claims: [ claim("渋谷にあります。", kind: "verifiable", ref: f) ])
    expect(result.status).to eq(:passed)
    expect(result.body).to eq("## 場所\n渋谷にあります。")
  end

  it "grounds a light rephrasing made only of the owner's words" do
    result = grounder.ground(body: "豆は農園から直接仕入れています。", claims: [ claim("豆は農園から直接仕入れています。", kind: "verifiable", slot_key: "offerings") ])
    expect(result.claims.sole).to include(review_status: "grounded", claim_kind: "experiential")
    expect(result.body).to eq("豆は農園から直接仕入れています。")
  end

  it "ignores a claim whose statement is not in the body" do
    result = grounder.ground(body: "渋谷にあるカフェです。", claims: [ claim("渋谷にあるカフェです。", kind: "verifiable", ref: f), claim("存在しない文", kind: "verifiable") ])
    expect(result.claims.size).to eq(1)
    expect(result.notes).to include(match(/not found/))
    expect(result.status).to eq(:passed)
  end
end
