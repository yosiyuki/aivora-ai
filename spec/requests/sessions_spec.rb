require "rails_helper"

RSpec.describe "Sessions", type: :request do
  let!(:user) { create_admin }
  before { create_site }

  it "requires login for the admin area and returns there afterwards" do
    get admin_root_path
    expect(response).to redirect_to(new_session_path)

    sign_in(user)
    expect(response).to redirect_to(admin_root_url)

    get admin_root_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("ログアウト")
  end

  it "rejects a wrong password" do
    sign_in(user, password: "wrong")
    expect(response).to redirect_to(new_session_path)
    follow_redirect!
    expect(response.body).to include(I18n.t("sessions.invalid"))
    get admin_root_path
    expect(response).to redirect_to(new_session_path)
  end

  it "signs out" do
    sign_in(user)
    delete session_path
    expect(response).to redirect_to(new_session_path)
    get admin_root_path
    expect(response).to redirect_to(new_session_path)
    expect(Session.count).to eq(0)
  end
end
