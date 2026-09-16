require "rails_helper"

RSpec.describe Public::Navigation do
  let(:site) { cafe_site }

  def publish!(page_type)
    item = site.content_items.create!(archetype_page_type: page_type, url: ContentItem.url_for(page_type))
    item.publish!(item.append_version!(body: "本文", title: page_type).tap { |v| v.decide!(:passed) })
    item
  end

  it "is empty without a site" do
    expect(described_class.for(nil)).to eq([])
  end

  it "lists only published pages, in the archetype's page_structure order" do
    publish!("faq")
    publish!("top")
    site.content_items.create!(archetype_page_type: "news", url: "/news") # never published

    entries = described_class.for(site)

    expect(entries.map(&:page_type)).to eq(%w[top faq]), "business order is top, services, faq, news"
    expect(entries.map(&:url)).to eq(%w[/ /faq])
  end

  it "labels pages for users instead of showing the page type key" do
    publish!("faq")

    expect(described_class.for(site).map(&:label)).to eq([ "よくある質問" ])
  end

  it "adds entries when an archetype is added, without moving an existing URL" do
    top = publish!("top")
    site.add_archetype(:media)
    articles = publish!("articles")

    entries = described_class.for(site)

    expect(entries.map(&:page_type)).to eq(%w[top articles])
    expect(top.reload.url).to eq("/"), "an existing URL never moves"
    expect(articles.url).to eq("/articles")
  end

  it "takes one query for the items regardless of how many pages exist" do
    %w[top faq news].each { |t| publish!(t) }
    site.reload

    queries = []
    callback = ->(_, _, _, _, payload) { queries << payload[:sql] if payload[:sql].include?("content_items") }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { described_class.for(site) }

    expect(queries.size).to eq(1)
  end
end
