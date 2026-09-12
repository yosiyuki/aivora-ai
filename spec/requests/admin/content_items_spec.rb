require "rails_helper"

RSpec.describe "Admin content items", type: :request do
  let!(:user) { create_admin }
  let!(:site) { cafe_site }

  before { sign_in(user) }

  it "lists pages and shows the published version with blanks as labels" do
    stub_generation
    Content::GenerateJob.perform_now(site.id, "top")
    item = site.reload.top_page

    get admin_content_items_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("渋谷のカフェ").and include("公開中")

    get admin_content_item_path(item)
    expect(response.body).to include("営業時間"), "blank shown by its label"
    expect(response.body).not_to include("slot:hours")
    expect(response.body).to include("（確認中）")
    expect(response.body).to include("根拠を確認済み")
    expect(response.body).not_to include("<textarea"), "observation only"
  end

  it "lists many pages without a query per row" do
    stub_generation
    Content::GenerateJob.perform_now(site.id, "top")
    %w[services faq news].each { |t| site.content_items.create!(archetype_page_type: t, url: "/#{t}").append_version!(body: "x") }
    queries = []
    counter = ->(*, payload) { queries << payload[:sql] unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get admin_content_items_path }
    expect(response).to have_http_status(:ok)
    expect(queries.grep(/FROM "content_versions"/).size).to be <= 2, "one query per association, not per row"
  end

  it "queues a regeneration and refuses while one is running" do
    stub_generation
    Content::GenerateJob.perform_now(site.id, "top")
    item = site.reload.top_page

    expect { post regenerate_admin_content_item_path(item) }.to have_enqueued_job(Content::GenerateJob).with(site.id, "top")
    expect(flash[:notice]).to eq(I18n.t("content.regenerate_queued"))

    item.update!(status: "generating")
    expect { post regenerate_admin_content_item_path(item) }.not_to have_enqueued_job
    expect(flash[:alert]).to eq(I18n.t("content.already_generating"))
  end

  it "does not exist on the public role" do
    with_app_role("public") do
      get "/admin/content_items"
      expect(response).to have_http_status(:not_found)
    end
  end
end
