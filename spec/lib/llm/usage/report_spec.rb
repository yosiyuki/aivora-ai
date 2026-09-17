require "rails_helper"

RSpec.describe Llm::Usage::Report do
  let!(:site) { cafe_site }

  def spend(amount, operation: "drafting", created_at: Time.current)
    LlmUsage.create!(site: site, operation_type: operation, model: "claude-opus-5",
                     estimated_cost: amount, created_at: created_at)
  end

  def publish_page!(page_type, created_at: Time.current, status: :passed)
    item = site.content_items.create!(archetype_page_type: page_type, url: ContentItem.url_for(page_type))
    version = item.append_version!(body: "本文", title: page_type, created_at: created_at)
    version.decide!(status)
    item.publish!(version) if status == :passed
    version
  end

  it "counts the pages that reached publication this month" do
    publish_page!("top")
    publish_page!("faq")
    publish_page!("news", status: :failed)

    expect(described_class.for(site).pages_this_month).to eq(2), "a failed version cost money but bought nothing"
  end

  it "ignores pages and spend from another month" do
    publish_page!("top", created_at: 2.months.ago)
    spend(30, created_at: 2.months.ago)

    report = described_class.for(site)

    expect(report.pages_this_month).to eq(0)
    expect(report.spent).to eq(0)
  end

  it "divides only the generation spend into a per-page figure" do
    publish_page!("top")
    spend(8, operation: "drafting")
    spend(2, operation: "grounding")
    spend(20, operation: "extraction") # interview: fixed cost, not this page's

    report = described_class.for(site)

    expect(report.generation_spend).to eq(BigDecimal("10"))
    expect(report.observation_spend).to eq(BigDecimal("20"))
    expect(report.cost_per_page).to eq(BigDecimal("10"))
  end

  it "falls back to a conservative estimate before anything has been generated" do
    report = described_class.for(site)

    expect(report.cost_per_page).to be_nil
    expect(report).to be_estimated
    expect(report.remaining_pages).to eq(4), "$50 buys roughly 3-5 pages (README §33)"
  end

  it "answers from measured cost once a page exists" do
    publish_page!("top")
    spend(10, operation: "drafting")

    report = described_class.for(site)

    expect(report).not_to be_estimated
    expect(report.remaining_pages).to eq(4), "$40 left at $10 a page"
  end

  it "says no more pages once the budget is spent" do
    publish_page!("top")
    spend(50, operation: "drafting")

    report = described_class.for(site)

    expect(report.remaining_pages).to eq(0)
    expect(report).to be_degraded
  end

  it "groups spend by operation for model routing review" do
    spend(3, operation: "drafting")
    spend(1, operation: "grounding")
    spend(6, operation: "extraction")

    expect(described_class.for(site).by_operation).to eq(
      "drafting" => BigDecimal("3"), "grounding" => BigDecimal("1"), "extraction" => BigDecimal("6")
    )
  end
end
