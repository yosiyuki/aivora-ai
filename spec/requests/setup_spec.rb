require "rails_helper"

RSpec.describe "First-run setup", type: :request do
  it "sends a fresh deployment to setup instead of the login form" do
    get admin_root_path
    expect(response).to redirect_to(setup_path)

    get new_session_path
    expect(response).to redirect_to(setup_path)
  end

  it "creates the admin, signs them in, then creates the single site" do
    get setup_path
    expect(response).to have_http_status(:ok)

    post setup_path, params: { user: { name: "管理者", email_address: "admin@example.com",
                                       password: "correct horse battery", password_confirmation: "correct horse battery" } }
    expect(response).to redirect_to(setup_site_path)
    expect(User.count).to eq(1)

    follow_redirect!
    expect(response).to have_http_status(:ok), "the new admin is signed in and reaches step 2"

    post setup_site_path, params: { site: { name: "渋谷のカフェ", domain: "https://cafe.example/menu" } }
    expect(response).to redirect_to(admin_interview_path)
    expect(Site.count).to eq(1)
    expect(Site.current.domain).to eq("cafe.example")

    follow_redirect!
    expect(response.body).to include("あなたの役割を教えてください")
  end

  it "re-renders the form with errors instead of creating a half-configured admin" do
    post setup_path, params: { user: { name: "", email_address: "nope", password: "a", password_confirmation: "b" } }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(User.count).to eq(0)
  end

  it "resumes at the site step when the admin exists but the site does not" do
    user = create_admin
    get setup_path
    expect(response).to redirect_to(setup_site_path)

    get setup_site_path
    expect(response).to redirect_to(new_session_path), "step 2 needs the admin signed in"

    sign_in(user)
    get setup_site_path
    expect(response).to have_http_status(:ok)
  end

  it "disappears once setup is complete" do
    create_admin
    create_site
    get setup_path
    expect(response).to have_http_status(:not_found)
    post setup_site_path, params: { site: { name: "x", domain: "y.example" } }
    expect(response).to have_http_status(:not_found)
    expect(Site.count).to eq(1)
  end
end
