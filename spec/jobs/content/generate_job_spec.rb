require "rails_helper"

RSpec.describe Content::GenerateJob, type: :job do
  let!(:site) { cafe_site }

  it "generates and publishes the top page" do
    stub_generation
    described_class.perform_now(site.id, "top")
    expect(site.reload.top_page).to be_published
    expect(site.top_page.versions.count).to eq(1)
  end

  it "produces one version when the same job runs twice concurrently" do
    stub_generation
    item, previous = ContentItem.claim_for_generation!(site, "top")
    expect(previous).to eq("draft")
    expect(item).to be_generating
    expect(ContentItem.claim_for_generation!(site, "top")).to be_nil, "second claim is refused"

    described_class.perform_now(site.id, "top")   # runs into the held claim and does nothing
    expect(ContentVersion.count).to eq(0)
    expect(Llm::Fake.calls).to be_empty
  end

  it "records a failed version and releases the claim when the model fails" do
    Llm::Fake.respond(:drafting) { raise Llm::RequestError.new("boom", retryable: true) }
    described_class.perform_now(site.id, "top")

    item = site.reload.top_page
    expect(item.status).to eq("draft")
    expect(item.latest_version).to be_failed
    expect(item.latest_version.metadata.dig("error", "message")).to eq("boom")
    expect(item).not_to be_published
  end

  it "keeps a published page published when a regeneration fails grounding" do
    stub_generation
    described_class.perform_now(site.id, "top")
    stub_generation(draft: "# 店\n## 営業時間は朝7時から\n本文。",
                    claims: [ { "statement" => "営業時間は朝7時から", "kind" => "verifiable", "support" => nil, "slot_key" => "hours", "confidence" => 0.9 } ])
    described_class.perform_now(site.id, "top")

    item = site.reload.top_page
    expect(item).to be_published
    expect(item.published_version.version).to eq(1)
    expect(item.latest_version).to be_failed
  end

  it "discards when the site no longer exists" do
    expect { described_class.perform_now(999_999, "top") }.not_to raise_error
  end
end
