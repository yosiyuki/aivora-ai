require "rails_helper"

RSpec.describe "Setup interview", type: :system do
  let!(:user) { create_admin(password: "correct horse battery") }
  let!(:site) { create_site(name: "渋谷のカフェ") }

  before do
    visit new_session_path
    fill_in "メールアドレス", with: user.email_address
    fill_in "パスワード", with: "correct horse battery"
    click_button "ログイン"
  end

  it "asks free-text questions with three examples, resumes, caps at ten and hands off", :aggregate_failures do
    click_link "ヒアリングを続ける"
    expect(page).to have_css("h1", text: "あなたの役割を教えてください")
    expect(page).to have_css("ul.examples li", count: 3)
    expect(page).not_to have_css("input[type=radio], input[type=checkbox], select")

    fill_in "あなたの答え", with: "渋谷でカフェをやっています。豆にこだわってます"
    click_button "送る"
    expect(page).to have_css("h1", text: "何について発信しますか")

    visit admin_root_path
    click_link "ヒアリングを続ける"
    expect(page).to have_css("h1", text: "何について発信しますか"), "resumes on the same question"

    9.times do |i|
      fill_in "あなたの答え", with: "自由記述の答え #{i}"
      click_button "送る"
    end
    expect(page).to have_content("一度ここまでで、ページを作ってみましょう")
    expect(page).not_to have_field("あなたの答え")
    expect(page).not_to have_content("スロット")

    click_button "ページを作る"
    expect(page).to have_current_path(admin_root_path)
    expect(page).to have_content("ヒアリングを終えました")
    expect(site.reload.status).to eq("active")
    expect(SourceItem.count).to eq(10)
  end
end
