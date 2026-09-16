require "rails_helper"

RSpec.describe "Public site", :slow, type: :system do
  let!(:site) { cafe_site }

  it "shows the published page and lets a visitor move between pages" do
    stub_generation
    Content::GenerateJob.perform_now(site.id, "top")
    faq = site.content_items.create!(archetype_page_type: "faq", url: "/faq")
    faq.publish!(faq.append_version!(body: "よくある質問の本文です。", title: "よくある質問").tap { |v| v.decide!(:passed) })

    visit "/"

    expect(page).to have_css("h1", text: "渋谷のカフェ")
    expect(page).to have_text("渋谷にある小さなカフェです")
    expect(page).to have_text("（確認中）"), "a blank stays visible as a question to the owner"
    expect(page).to have_no_link("ログアウト"), "no admin chrome"

    click_link "よくある質問"

    expect(page).to have_current_path("/faq")
    expect(page).to have_text("よくある質問の本文です")
  end

  it "does not link a page that is not published" do
    stub_generation
    Content::GenerateJob.perform_now(site.id, "top")
    site.content_items.create!(archetype_page_type: "news", url: "/news")

    visit "/"

    expect(page).to have_no_link("お知らせ")
  end
end
