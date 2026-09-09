require "rails_helper"

RSpec.describe "Admin interview", type: :request do
  let!(:user) { create_admin }
  let!(:site) { create_site }

  it "requires login" do
    get admin_interview_path
    expect(response).to redirect_to(new_session_path)
  end

  it "asks, records, and resumes" do
    sign_in(user)
    get admin_interview_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("あなたの役割を教えてください")
    expect(Nokogiri::HTML(response.body).css("ul.examples li").size).to eq(3)

    post answer_admin_interview_path, params: { answer: "店主です" }
    expect(response).to redirect_to(admin_interview_path)
    expect(site.current_interview.turns.first.answer_text).to eq("店主です")
    expect(SourceItem.count).to eq(1)

    get admin_interview_path
    expect(response.body).to include("何について発信しますか")
  end

  it "rejects a blank answer with a message" do
    sign_in(user)
    get admin_interview_path
    post answer_admin_interview_path, params: { answer: " " }
    expect(response).to redirect_to(admin_interview_path)
    expect(flash[:alert]).to eq(I18n.t("interview.blank_answer"))
  end

  it "finishes and sends the user to the dashboard" do
    sign_in(user)
    get admin_interview_path
    post finish_admin_interview_path
    expect(response).to redirect_to(admin_root_path)
    expect(site.current_interview).to be_completed
    expect(site.reload.status).to eq("active")

    get admin_interview_path
    expect(response).to redirect_to(admin_root_path)
  end

  it "does not exist on the public role" do
    with_app_role("public") do
      get "/admin/interview"
      expect(response).to have_http_status(:not_found)
    end
  end
end
