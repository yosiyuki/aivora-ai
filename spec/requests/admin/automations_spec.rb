require "rails_helper"

RSpec.describe "Admin automation (Emergency Stop)", type: :request do
  let!(:user) { create_admin }
  let!(:site) { cafe_site }

  before { sign_in(user) }

  it "freezes generation from the dashboard and says what keeps running" do
    post freeze_admin_automation_path

    expect(response).to redirect_to(admin_root_path)
    expect(site.policy.reload).to be_frozen

    get admin_root_path
    expect(response.body).to include("ページの作成を止めています")
    expect(response.body).to include("点検は続いています")
    expect(response.body).to include("再開する")
    expect(response.body).not_to include("停止")
  end

  it "resumes" do
    site.policy.freeze_automation!

    post resume_admin_automation_path

    expect(site.policy.reload).not_to be_frozen
    get admin_root_path
    expect(response.body).to include("ページの作成を止める")
  end

  it "keeps the original freeze time when frozen twice" do
    site.policy.freeze_automation!
    first = site.policy.reload.automation_frozen_at

    travel 1.hour do
      post freeze_admin_automation_path
    end

    expect(site.policy.reload.automation_frozen_at).to be_within(1.second).of(first)
  end
end
