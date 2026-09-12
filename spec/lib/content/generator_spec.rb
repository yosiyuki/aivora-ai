require "rails_helper"

RSpec.describe Content::Generator do
  let!(:site) { cafe_site }

  it "writes one article from interview knowledge alone and publishes it when grounding passes", :aggregate_failures do
    stub_generation
    version = described_class.new(site, page_type: "top").generate!

    item = site.reload.top_page
    expect(item).to have_attributes(url: "/", status: "published", published_version: version, title: "渋谷のカフェ")
    expect(version).to be_passed
    expect(version.body).to include("[[slot:hours]]")
    expect(version.claims.pluck(:claim_kind).uniq).to contain_exactly("verifiable", "experiential", "general")
    expect(version.claims.where(review_status: "grounded").count).to eq(4)
    expect(version).to be_readonly, "decided versions are frozen"
    expect(version.blanks.count).to eq(0), "the drafter's placeholder is recorded in metadata, not as a claim"
    expect(version.metadata["blanks"]).to include("slot_key" => "hours", "statement" => nil)
    expect(version.metadata["llm_usage_ids"].size).to eq(2), "exactly two LLM calls per page"
    expect(Llm::Fake.calls.size).to eq(2)
  end

  it "writes from experiences alone when there are no facts" do
    Fact.find_each { |f| f.update!(status: "retired") }
    site.reload
    stub_generation(draft: "# 渋谷のカフェ\n豆は農園から直接仕入れて自分で焙煎しています。",
                    claims: [ { "statement" => "豆は農園から直接仕入れて自分で焙煎しています。", "kind" => "experiential", "support" => { "ref" => "E1" }, "slot_key" => nil, "confidence" => 0.9 } ])
    version = described_class.new(site, page_type: "top").generate!
    expect(version).to be_passed
    expect(site.reload.top_page).to be_published
  end

  it "records a failed version and does not publish when grounding fails" do
    stub_generation(draft: "# 店\n## 営業時間は朝7時から\n本文。",
                    claims: [ { "statement" => "営業時間は朝7時から", "kind" => "verifiable", "support" => nil, "slot_key" => "hours", "confidence" => 0.9 } ])
    version = described_class.new(site, page_type: "top").generate!
    expect(version).to be_failed
    expect(site.reload.top_page).not_to be_published
    expect(site.top_page.published_version).to be_nil
  end

  it "appends a regenerated version and never rewrites the first" do
    stub_generation
    first = described_class.new(site, page_type: "top").generate!
    second = described_class.new(site, page_type: "top").generate!
    expect(second.version).to eq(2)
    expect(second.source).to eq("regenerated")
    expect(first.reload.body).to be_present
    expect(site.reload.top_page.published_version).to eq(second)
  end

  it "creates no version when the model fails" do
    Llm::Fake.respond(:drafting) { raise Llm::RequestError.new("boom", retryable: true) }
    expect { described_class.new(site, page_type: "top").generate! }.to raise_error(Llm::RequestError)
    expect(ContentVersion.count).to eq(0)
    expect(LlmUsage.sole).not_to be_succeeded
  end
end
