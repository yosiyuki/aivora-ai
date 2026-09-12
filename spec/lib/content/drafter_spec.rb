require "rails_helper"

RSpec.describe Content::Drafter do
  let!(:site) { cafe_site }
  let(:pack) { Content::KnowledgePack.for(site, page_type: "top") }

  it "sends the pack as material, the editorial policy in the system prompt, and parses title/body" do
    Llm::Fake.respond(:drafting) { cafe_draft }
    draft = described_class.new(pack).draft

    expect(draft.title).to eq("渋谷のカフェ")
    expect(draft.body).to start_with("渋谷にある小さなカフェです。")
    expect(draft.body).not_to include("# 渋谷のカフェ")

    call = Llm::Fake.calls.sole
    expect(call.system).to include("誇張しない").and include("[[slot:キー]]").and include("訪問者が最初に読む紹介ページ")
    expect(call.messages.sole[:content]).to include("F1: 渋谷のカフェ の 場所 = 渋谷").and include("hours=営業時間")
    expect(call.schema).to be_nil
    expect(LlmUsage.sole.operation_type).to eq("drafting")
  end

  it "never uses the model's title: titles are generated from the subject" do
    Llm::Fake.respond(:drafting) { "# 地域No.1 24時間営業のカフェ\n本文。" }
    expect(described_class.new(pack).draft).to have_attributes(title: "渋谷のカフェ", body: "本文。")
    expect(described_class.title_for(Content::KnowledgePack.for(site, page_type: "faq"))).to eq("よくある質問")
  end
end
