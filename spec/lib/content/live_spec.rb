require "rails_helper"

# The two unverified premises from the plan: does interview knowledge alone
# make an article, and does claim classification work in practice?
RSpec.describe "Content generation live", :live do
  it "produces a grounded top page for 渋谷でカフェ" do
    skip "LLM_API_KEY not set" if ENV["LLM_API_KEY"].blank?

    site = cafe_site
    adapter = Llm::Anthropic.new(api_key: ENV["LLM_API_KEY"])
    pack = Content::KnowledgePack.for(site, page_type: "top")
    drafter = Content::Drafter.new(pack, client: Llm::Client.new(operation: :drafting, adapter: adapter, model: "claude-opus-5", effort: :high, max_tokens: 8000))
    extractor = Content::ClaimExtractor.new(pack, client: Llm::Client.new(operation: :grounding, adapter: adapter, model: "claude-opus-5", effort: :medium, max_tokens: 4096))

    draft = drafter.draft
    claims = extractor.extract(draft.body)
    result = Content::Grounder.new(pack).ground(body: draft.body, claims: claims)

    puts "\n--- title ---\n#{draft.title}\n--- body ---\n#{result.body}\n--- claims ---"
    result.claims.each { |c| puts "#{c[:review_status].ljust(9)} #{c[:claim_kind].ljust(12)} #{c[:statement]}" }
    puts "notes: #{result.notes.inspect}"

    expect(result.status).to eq(:passed)
    expect(result.claims.map { |c| c[:claim_kind] }.uniq.size).to be >= 2
  end
end
