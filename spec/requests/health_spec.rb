require "rails_helper"

RSpec.describe "Health checks per process role", type: :request do
  describe "web role" do
    it "serves the PaaS health check and the admin one" do
      with_app_role("web") do
        get "/up"
        expect(response).to have_http_status(:ok)

        get "/admin/up"
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "public role" do
    it "serves the PaaS health check but has no admin routes" do
      with_app_role("public") do
        get "/up"
        expect(response).to have_http_status(:ok)

        get "/admin/up"
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
