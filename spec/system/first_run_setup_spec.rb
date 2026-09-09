require "rails_helper"

# The one flow a human must complete: Create Admin -> Enter Site URL.
RSpec.describe "First-run setup", type: :system do
  it "walks a fresh deployment from /admin to a configured dashboard", :aggregate_failures do
    visit admin_root_path
    expect(page).to have_current_path(setup_path)
    expect(page).to have_content("ステップ 1 / 2")
    expect(page).to have_css("h1", text: "管理者を作成")

    fill_in "お名前", with: "管理者"
    fill_in "メールアドレス", with: "Admin@Example.com"
    fill_in "パスワード", with: "correct horse battery", match: :prefer_exact
    fill_in "パスワード（確認）", with: "correct horse battery"
    click_button "次へ"

    expect(page).to have_current_path(setup_site_path)
    expect(page).to have_content("ステップ 2 / 2")
    expect(page).to have_css("h1", text: "サイトの情報")

    fill_in "サイト名", with: "渋谷のカフェ"
    fill_in "ドメイン", with: "https://cafe.example/menu?x=1"
    click_button "設定を完了する"

    expect(page).to have_current_path(admin_root_path)
    expect(page).to have_content("初期設定が完了しました")
    expect(page).to have_css("dd", text: "渋谷のカフェ")
    expect(page).to have_css("dd", text: "cafe.example")
    expect(page).to have_button("ログアウト")

    expect(User.pick(:email_address)).to eq("admin@example.com")
    expect(Site.current.domain).to eq("cafe.example")

    visit setup_path
    expect(page.status_code).to eq(404)
  end

  it "keeps the admin form with Japanese errors when input is invalid", :aggregate_failures do
    visit setup_path
    fill_in "お名前", with: ""
    fill_in "メールアドレス", with: "not-an-email"
    fill_in "パスワード", with: "short", match: :prefer_exact
    fill_in "パスワード（確認）", with: "different"
    click_button "次へ"

    expect(page.status_code).to eq(422)
    expect(page).to have_css(".errors")
    expect(page).to have_content("お名前を入力してください")
    expect(page).to have_content("メールアドレスは不正な値です")
    expect(page).to have_content("パスワード（確認）とパスワードの入力が一致しません")
    expect(User.count).to eq(0)
  end
end
