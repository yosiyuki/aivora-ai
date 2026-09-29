require "rails_helper"

RSpec.describe "First page after the interview", type: :system do
  include ActiveJob::TestHelper

  let!(:user) { create_admin(password: "correct horse battery") }
  let!(:site) { cafe_site }

  before do
    visit new_session_path
    fill_in "メールアドレス", with: user.email_address
    fill_in "パスワード", with: "correct horse battery"
    click_button "ログイン"
  end

  it "goes from finishing the interview to a published page with visible blanks", :aggregate_failures do
    stub_generation
    interview = site.interviews.create!
    runner = Interviewing::Runner.new(interview, question_source: Interviewing::FixedQuestionSource.new)
    3.times { |i| runner.answer!("答え #{i}") }

    click_link "ヒアリングを続ける"
    click_button "ページを作る"
    expect(page).to have_content("最初のページを作成中です")

    perform_enqueued_jobs
    visit admin_root_path
    expect(page).to have_content("最初のページを公開しました")

    click_link "ページを見る"
    expect(page).to have_css("h1", text: "渋谷のカフェ")
    expect(page).to have_content("あと 1 か所、あとで教えてください")
    expect(page).to have_content("営業時間")
    expect(page).to have_css(".page-preview .blank", text: "（確認中）")
    expect(page).to have_button("もう一度作る")
  end

  it "grows the site beyond the front page from the same interview" do
    stub_generation
    perform_enqueued_jobs { Content::GenerateJob.perform_now(site.id, "top") }
    stub_generation(page_type: "faq")
    perform_enqueued_jobs { Content::GenerateJob.perform_now(site.id, "faq") }

    visit "/"

    expect(page).to have_link("よくある質問")
    click_link "よくある質問"
    expect(page).to have_text("駐車場はありますか")
  end
end
