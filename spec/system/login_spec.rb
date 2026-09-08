require "rails_helper"

RSpec.describe "Login", type: :system do
  let!(:user) { create_admin(password: "correct horse battery") }
  before { create_site(name: "渋谷のカフェ") }

  it "rejects a wrong password, accepts the right one, and signs out", :aggregate_failures do
    visit admin_root_path
    expect(page).to have_current_path(new_session_path)
    expect(page).to have_css("h1", text: "ログイン")

    fill_in "メールアドレス", with: user.email_address
    fill_in "パスワード", with: "wrong"
    click_button "ログイン"
    expect(page).to have_current_path(new_session_path)
    expect(page).to have_css(".flash.alert", text: "メールアドレスかパスワードが違います")

    fill_in "メールアドレス", with: user.email_address
    fill_in "パスワード", with: "correct horse battery"
    click_button "ログイン"
    expect(page).to have_current_path(admin_root_path)
    expect(page).to have_css("h1", text: "ダッシュボード")
    expect(page).to have_link("渋谷のカフェ", href: admin_root_path)

    click_button "ログアウト"
    expect(page).to have_current_path(new_session_path)
    expect(page).to have_css(".flash.notice", text: "ログアウトしました")

    visit admin_root_path
    expect(page).to have_current_path(new_session_path)
  end
end
