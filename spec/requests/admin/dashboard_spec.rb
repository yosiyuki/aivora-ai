require "rails_helper"

RSpec.describe "Admin dashboard", type: :request do
  let!(:user) { create_admin }
  let!(:site) { cafe_site }

  before { sign_in(user) }

  def spend(amount, operation: "drafting")
    LlmUsage.create!(site: site, operation_type: operation, model: "claude-opus-5", estimated_cost: amount)
    Current.llm_budgets = nil
  end

  it "reports the month in outcomes, with the amount secondary" do
    stub_generation
    Content::GenerateJob.perform_now(site.id, "top")
    spend(10)

    get admin_root_path

    expect(response.body).to include("今月は 1 ページ作りました")
    expect(response.body).to include("あと 4 ページほど作れます")
    expect(response.body).to include("$10.00").and include("$50")
  end

  it "estimates before anything has been generated, rather than saying zero" do
    get admin_root_path

    expect(response.body).to include("今月はまだページを作っていません")
    expect(response.body).to include("ほど作れる見込みです")
  end

  it "never shows tokens, model names or thresholds" do
    spend(10)

    get admin_root_path

    expect(response.body).not_to include("claude")
    expect(response.body).not_to match(/token/i)
    expect(response.body).not_to include("drafting")
    expect(response.body).not_to include("grounding")
  end

  it "explains that an overrun keeps running instead of stopping" do
    spend(60)

    get admin_root_path

    expect(response.body).to include("切り替えて続けています")
    expect(response.body).not_to include("停止")
    expect(response.body).to include("根拠の確認はこれまでどおり")
  end
end
