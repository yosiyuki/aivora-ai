require "rails_helper"

RSpec.describe "Public pages", type: :request do
  let!(:site) { cafe_site }

  def publish_top!
    stub_generation
    Content::GenerateJob.perform_now(site.id, "top")
    site.reload.top_page
  end

  it "serves the published page to anonymous visitors" do
    create_admin # a deployment past setup still serves the public site anonymously
    item = publish_top!

    get item.url

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("渋谷にある小さなカフェです")
    expect(response.body).not_to include("ログアウト"), "no admin chrome on the public page"
  end

  it "shows a blank as 確認中 rather than hiding it" do
    publish_top!

    get "/"

    expect(response.body).to include("（確認中）")
    expect(response.body).not_to include("slot:hours"), "the raw key is never shown"
  end

  it "renders the canonical link and the page language" do
    item = publish_top!

    get "/"

    expect(response.body).to include(%(rel="canonical"))
    expect(response.body).to include(%(href="#{item.url}"))
    expect(response.body).to include(%(lang="#{item.language}"))
  end

  it "does not emit a meta description generated from the body" do
    publish_top!

    get "/"

    expect(response.body).not_to match(/<meta[^>]+name="description"/)
  end

  it "404s an unpublished page even though it keeps its published version" do
    item = publish_top!
    item.unpublish!

    get "/"

    expect(response).to have_http_status(:not_found)
    expect(item.reload.published_version).to be_present, "the pointer is kept for restore"
  end

  it "404s a page that has never been published" do
    site.content_items.create!(archetype_page_type: "faq", url: "/faq")

    get "/faq"

    expect(response).to have_http_status(:not_found)
  end

  it "404s a page whose only version failed grounding" do
    item = site.content_items.create!(archetype_page_type: "faq", url: "/faq")
    item.append_version!(body: "x").decide!(:failed)

    get "/faq"

    expect(response).to have_http_status(:not_found)
  end

  it "404s an unknown path" do
    publish_top!

    get "/nothing-here"

    expect(response).to have_http_status(:not_found)
    expect(response.body).to include("ページが見つかりません")
  end

  it "404s before the site exists" do
    # A site is never deleted (nothing in this system is), so the pre-setup
    # state is the one where Site.current finds no row.
    allow(Site).to receive(:current).and_return(nil)

    get "/"

    expect(response).to have_http_status(:not_found)
  end

  it "resolves a page by the URL it was issued, ignoring a trailing slash" do
    item = site.content_items.create!(archetype_page_type: "faq", url: "/faq")
    item.publish!(item.append_version!(body: "よくある質問です。").tap { |v| v.decide!(:passed) })

    get "/faq/"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("よくある質問です")
  end

  it "answers a conditional GET with 304 while the version is unchanged" do
    publish_top!
    get "/"
    etag = response.headers["ETag"]

    get "/", headers: { "HTTP_IF_NONE_MATCH" => etag }

    expect(response).to have_http_status(:not_modified)
  end

  it "keeps the admin routes reachable behind the catch-all" do
    user = create_admin
    sign_in(user)

    get admin_root_path

    expect(response).to have_http_status(:ok)
  end
end
