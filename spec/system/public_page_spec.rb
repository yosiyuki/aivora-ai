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

  it "reaches an article from the article list" do
    site.add_archetype(:media)
    stub_generation
    Content::GenerateJob.perform_now(site.id, "top")
    exp = site.experiences.find_by!(summary: "自家焙煎")
    stub_article_generation(exp)
    Content::GenerateJob.perform_now(site.id, "article", "Experience", exp.id)

    visit "/"
    click_link "記事"
    expect(page).to have_current_path("/articles")
    click_link "自家焙煎"

    expect(page).to have_current_path("/article/#{exp.id}")
    expect(page).to have_text("豆は農園から直接仕入れて自分で焙煎しています")
  end
end
