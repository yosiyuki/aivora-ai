require "rails_helper"

RSpec.describe "Verification requests", :slow, type: :system do
  include ActiveJob::TestHelper

  let!(:user) { create_admin }
  let!(:site) { cafe_site }

  before do
    visit new_session_path
    fill_in "メールアドレス", with: user.email_address
    fill_in "パスワード", with: "correct horse battery"
    click_button "ログイン"
  end

  it "asks about the blank in the page and puts the answer back into it" do
    stub_generation
    perform_enqueued_jobs { Content::GenerateJob.perform_now(site.id, "top") }

    visit admin_content_item_path(site.reload.top_page)

    expect(page).to have_text("営業時間"), "the blank is shown by its label"
    click_link "分かるものを教える"

    expect(page).to have_current_path(admin_verifications_path)
    expect(page).to have_text("営業時間")
    expect(page).to have_no_text("hours"), "the key is never shown"

    Llm::Fake.respond(:extraction) do
      { "answered" => true, "value" => "7時-17時", "source_text" => "朝7時から夕方5時まで", "confidence" => 0.9 }
    end

    hours = site.verification_requests.find_by(slot_key: "hours")
    within("#verification_#{hours.id}") do
      fill_in "answer_#{hours.id}", with: "朝7時から夕方5時まで開けています"
      perform_enqueued_jobs { click_button "答える" }
    end

    expect(page).to have_text("ありがとうございます")

    fact = site.primary_entity.facts.for_slot("hours").sole
    expect(fact).to be_accepted
    expect(fact.value).to eq("7時-17時")
  end

  it "lets the owner put a question aside" do
    site.verification_requests.create!(request_type: "initial", slot_key: "hours",
                                       question: "営業時間を教えてください。", priority: 290)

    visit admin_verifications_path
    click_button "今は答えない"

    expect(page).to have_text("またあとでお聞きします")
    expect(page).to have_text("お聞きしたいことはありません")
  end
end
