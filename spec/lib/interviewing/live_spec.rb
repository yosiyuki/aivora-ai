require "rails_helper"

# The unverified premise from the plan: can the model get an entity and an
# archetype out of "渋谷でカフェ"? Runs only with LIVE_LLM=1 and LLM_API_KEY.
RSpec.describe "Interview extraction live", :live do
  it "infers business and a primary entity from one sentence" do
    skip "LLM_API_KEY not set" if ENV["LLM_API_KEY"].blank?

    site = Site.create!(name: "テスト", domain: "example.com")
    interview = site.interviews.create!
    client = Llm::Client.new(operation: :extraction, adapter: Llm::Anthropic.new(api_key: ENV["LLM_API_KEY"]),
                             model: "claude-opus-5", effort: :medium, max_tokens: 4096)
    runner = Interviewing::Runner.new(interview, question_source: Interviewing::FixedQuestionSource.new)
    processor = Interviewing::Processor.new(interview, agent: Interviewing::ExtractionAgent.new(interview, client: client))

    runner.answer!("カフェの店主です")
    runner.answer_and_process!("渋谷でカフェをやっています。豆にこだわってます", processor: processor)

    expect(site.reload.primary_entity&.entity_type).to eq("business")
    expect(interview.reload.archetype_hypothesis).to eq("business")
    expect(interview.pending_question).to be_present
    puts "\nnext question: #{interview.pending_question["text"]}\nexamples: #{interview.pending_question["examples"]}"
  end
end
