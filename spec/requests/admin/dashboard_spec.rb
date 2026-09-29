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

  describe "knowledge health" do
    it "shows one number and turns each count into something to do" do
      stub_generation
      Content::GenerateJob.perform_now(site.id, "top")

      get admin_root_path

      expect(response.body).to match(/\d+%/)
      expect(response.body).to include("教えてほしいことが")
      expect(response.body).not_to include("slot"), "no slot keys"
      expect(response.body).not_to include("hours")
    end

    it "says nothing needs doing when nothing does" do
      site.required_slots.each do |s|
        next if s.key == "location"
        f = site.primary_entity.facts.create!(attribute_key: s.key, slot_key: s.key, value_json: { "value" => "x" }, confidence: 0.9)
        f.accept!(evidence: owner_evidence(site, text: "x です"))
      end

      get admin_root_path

      expect(response.body).to include("100%")
      expect(response.body).to include("いま確認が必要なことはありません")
    end

    it "waits for the interview before scoring" do
      allow(Knowledge::Health).to receive(:for).and_return(instance_double(Knowledge::Health, score: nil))

      get admin_root_path

      expect(response.body).to include("ヒアリングが終わると計算できます")
    end
  end

  describe "product KPIs" do
    it "phrases each rate as counts and never as a percentage" do
      r = site.verification_requests.create!(request_type: "initial", slot_key: "hours", question: "q", priority: 1)
      r.update!(status: "answered")
      site.verification_requests.create!(request_type: "initial", slot_key: "contact", question: "q", priority: 1)

      get admin_root_path

      expect(response.body).to include("2 件のうち 1 件にお答えいただきました")
      expect(response.body).not_to match(/\b50%/)
    end

    it "leaves a KPI out while it has nothing to say" do
      get admin_root_path

      expect(response.body).not_to include("お答えいただきました")
      expect(response.body).not_to include("古くなった情報")
    end
  end
end
