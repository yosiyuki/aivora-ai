require "rails_helper"

RSpec.describe "Public sitemap and robots", type: :request do
  let!(:site) { cafe_site }

  def publish!(page_type)
    item = site.content_items.create!(archetype_page_type: page_type, url: ContentItem.url_for(page_type))
    item.publish!(item.append_version!(body: "本文", title: page_type).tap { |v| v.decide!(:passed) })
    item
  end

  it "lists published pages only, as absolute URLs on the serving host, with lastmod" do
    top = publish!("top")
    faq = publish!("faq")
    site.content_items.create!(archetype_page_type: "news", url: "/news")            # never published
    gone = publish!("services"); gone.unpublish!

    get "/sitemap.xml"

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/xml")
    doc = Nokogiri::XML(response.body)
    locs = doc.css("url loc").map(&:text)
    expect(locs).to contain_exactly("http://www.example.com/", "http://www.example.com/faq")
    expect(locs).not_to include(a_string_including("/news"), a_string_including("/services"))
    expect(doc.css("url lastmod").first.text).to eq(top.published_version.created_at.utc.iso8601)
    expect(faq.published_version).to be_present
  end

  it "is an empty urlset before the site exists" do
    allow(Site).to receive(:current).and_return(nil)

    get "/sitemap.xml"

    expect(response).to have_http_status(:ok)
    expect(Nokogiri::XML(response.body).css("url")).to be_empty
  end

  it "is served to anonymous visitors and answers a conditional GET with 304" do
    publish!("top")
    get "/sitemap.xml"
    etag = response.headers["ETag"]

    get "/sitemap.xml", headers: { "HTTP_IF_NONE_MATCH" => etag }

    expect(response).to have_http_status(:not_modified)
  end

  it "points robots.txt at the sitemap on the same host and keeps the admin out" do
    get "/robots.txt"

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/plain")
    expect(response.body).to include("Sitemap: http://www.example.com/sitemap.xml")
    expect(response.body).to include("Disallow: /admin")
    expect(Rails.root.join("public/robots.txt")).not_to exist, "a static file would shadow this route"
  end
end
