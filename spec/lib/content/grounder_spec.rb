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

  it "passes a fully grounded draft and records grounded claims with offsets", :aggregate_failures do
    result = grounder.ground(body: cafe_draft.lines[2..].join, claims: cafe_claims(pack))
    expect(result.status).to eq(:passed)
    expect(result.body).to include("場所は渋谷です。")
    grounded = result.claims.select { |c| c[:review_status] == "grounded" }
    expect(grounded.map { |c| c[:knowledge_type] }).to contain_exactly("Fact", "Experience", "Experience", "Fact")
    expect(grounded.first[:start_offset]).to be_a(Integer)
    expect(result.blanks).to include("slot_key" => "hours", "statement" => nil), "the drafter's own placeholder is a blank"
  end

  it "removes a verifiable sentence with no fact behind it and leaves the slot in its place" do
    body = "渋谷にあるカフェです。営業時間は朝7時から夕方5時までです。豆は農園から直接仕入れて自分で焙煎しています。"
    claims = [ claim("渋谷にあるカフェです。", kind: "verifiable", ref: f),
               claim("営業時間は朝7時から夕方5時までです。", kind: "verifiable", ref: nil, slot_key: "hours"),
               claim("豆は農園から直接仕入れて自分で焙煎しています。", kind: "experiential", ref: e1) ]
    result = grounder.ground(body: body, claims: claims)

    expect(result.status).to eq(:passed)
    expect(result.body).to eq("渋谷にあるカフェです。[[slot:hours]]豆は農園から直接仕入れて自分で焙煎しています。")
    blank = result.claims.find { |c| c[:review_status] == "blank" }
    expect(blank).to include(slot_key: "hours", grounded: false, knowledge_type: nil)
    expect(result.blanks).to eq([ { "slot_key" => "hours", "statement" => "営業時間は朝7時から夕方5時までです。" } ])
  end

  it "does not trust a fact reference whose value is not in the sentence" do
    result = grounder.ground(body: "新宿にあるカフェです。", claims: [ claim("新宿にあるカフェです。", kind: "verifiable", ref: f) ])
    expect(result.body).to eq("[[slot:location]]")
    expect(result.claims.sole[:review_status]).to eq("blank")
  end

  it "grounds a sentence in the owner's own words even when the model called it verifiable" do
    body = "コーヒーの豆は、農園から直接仕入れて、自分で焙煎しています。店内は、一人でも長居しやすい静かな雰囲気にしています。"
    claims = [ claim("コーヒーの豆は、農園から直接仕入れて、自分で焙煎しています。", kind: "verifiable", slot_key: "offerings"),
               claim("店内は、一人でも長居しやすい静かな雰囲気にしています。", kind: "verifiable") ]
    result = grounder.ground(body: body, claims: claims)
    expect(result.body).to eq(body)
    expect(result.claims.map { |c| c[:review_status] }).to eq(%w[grounded grounded])
    expect(result.claims.map { |c| c[:claim_kind] }).to eq(%w[experiential experiential])
    expect(result.claims.map { |c| c[:knowledge_type] }).to eq(%w[Experience Experience])
  end

  it "removes an ungrounded verifiable sentence outright when no slot fits, instead of leaving filler" do
    result = grounder.ground(body: "渋谷にあるカフェです。豆の仕入れから焙煎までを自分でやっていること、そして静かな店内であること。",
                             claims: [ claim("渋谷にあるカフェです。", kind: "verifiable", ref: f),
                                       claim("豆の仕入れから焙煎までを自分でやっていること、そして静かな店内であること。", kind: "verifiable") ])
    expect(result.body).to eq("渋谷にあるカフェです。")
    expect(result.body).not_to include("unknown")
    expect(result.claims.last[:review_status]).to eq("excised")
  end

  it "excises an experiential sentence with no experience behind it" do
    body = "渋谷にあるカフェです。常連さんはみんな笑顔で帰ります。"
    result = grounder.ground(body: body, claims: [ claim("渋谷にあるカフェです。", kind: "verifiable", ref: f),
                                                    claim("常連さんはみんな笑顔で帰ります。", kind: "experiential") ])
    expect(result.body).to eq("渋谷にあるカフェです。")
    expect(result.claims.last).to include(review_status: "excised", grounded: false)
  end

  it "keeps general claims without turning them into knowledge" do
    result = grounder.ground(body: "コーヒーにはカフェインが含まれます。", claims: [ claim("コーヒーにはカフェインが含まれます。", kind: "general") ])
    expect(result.body).to eq("コーヒーにはカフェインが含まれます。")
    expect(result.claims.sole).to include(review_status: "general", grounded: true, knowledge_type: nil)
  end

  it "fails the version when an ungrounded claim sits in a heading" do
    body = "## 営業時間は朝7時から\n本文。"
    result = grounder.ground(body: body, claims: [ claim("営業時間は朝7時から", kind: "verifiable", slot_key: "hours") ])
    expect(result.status).to eq(:failed)
    expect(result.notes).to include(match(/heading/))
  end

  it "drops unknown placeholder keys and collapses repeats within a paragraph" do
    result = grounder.ground(body: "駐車場は [[slot:parking]] です。[[slot:hours]] と [[slot:hours]]。", claims: [])
    expect(result.body).to eq("駐車場は  です。[[slot:hours]] と 。".gsub(/[ \t]{2,}/, " "))
    expect(result.blanks.map { |b| b["slot_key"] }).to contain_exactly("hours")
  end

  it "ignores a claim whose statement is not in the body" do
    result = grounder.ground(body: "渋谷にあるカフェです。", claims: [ claim("存在しない文", kind: "verifiable") ])
    expect(result.claims).to be_empty
    expect(result.notes.sole).to include("not found")
    expect(result.status).to eq(:passed)
  end
end
