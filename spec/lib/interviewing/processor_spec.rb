require "rails_helper"

RSpec.describe Interviewing::Processor do
  let!(:site) { create_site }
  let(:interview) { site.interviews.create! }
  let(:runner) { Interviewing::Runner.new(interview) }

  it "runs the agent, routes, resolves, and hands the model's question to the runner" do
    Llm::Fake.respond(:extraction) { cafe_output }
    runner.answer_and_process!("渋谷でカフェをやっています。豆にこだわってます")

    turn = interview.turns.first.reload
    expect(turn).to be_extracted
    expect(LlmUsage.sole).to have_attributes(operation_type: "extraction", related: turn.source_item)
    expect(site.reload.primary_archetype).to eq("business")

    next_turn = runner.current_turn
    expect(next_turn.question_text).to include("農園から直接"), "quotes the user's own words"
    expect(next_turn.question_kind).to eq("slot:story")
    expect(next_turn.examples.size).to eq(3)
  end

  it "sends the untrusted answer in the user turn with the slot vocabulary in the system prompt" do
    Llm::Fake.respond(:extraction) { cafe_output }
    runner.answer_and_process!("UNTRUSTED ANSWER")
    call = Llm::Fake.calls.sole
    expect(call.messages.sole[:content]).to include("UNTRUSTED ANSWER")
    expect(call.system).not_to include("UNTRUSTED ANSWER")
    expect(call.system).to include("hours=営業時間")
    expect(call.schema.dig(:properties, :facts, :items, :properties, :slot, :anyOf, 0, :enum)).to include("hours", "topic")
  end

  it "adapts the system prompt to the detected role" do
    site.update!(user_role: "individual")
    Llm::Fake.respond(:extraction) { cafe_output }
    runner.answer_and_process!("趣味の話を書きたい")
    expect(Llm::Fake.calls.sole.system).to include("目標を数字で聞かず")
  end

  it "keeps the interview going on an LLM failure and falls back to fixed questions" do
    Llm::Fake.respond(:extraction) { raise Llm::RequestError.new("boom", retryable: true) }
    runner.answer_and_process!("店主です")

    turn = interview.turns.first.reload
    expect(turn.extraction_status).to eq("failed")
    expect(turn.extraction_error).to include("boom")
    expect(turn.answer_text).to eq("店主です"), "the answer itself is never lost"
    expect(LlmUsage.sole).not_to be_succeeded

    next_turn = runner.current_turn
    expect(next_turn.question_kind).to eq("topic"), "fixed question source takes over"
  end

  it "never calls the model twice for the same answer, even after a failure" do
    Llm::Fake.respond(:extraction) { raise Llm::RequestError.new("boom", retryable: true) }
    first = runner.current_turn
    runner.answer_and_process!("店主です", turn_id: first.id)
    expect(first.reload.extraction_status).to eq("failed")

    runner.answer_and_process!("店主です", turn_id: first.id)   # idempotent resubmit of the same turn
    expect(Llm::Fake.calls.size).to eq(1)
    expect(first.reload.extraction_status).to eq("failed")
  end

  it "skips a turn another request already claimed" do
    Llm::Fake.respond(:extraction) { cafe_output }
    turn = runner.answer!("渋谷でカフェをやっています")
    turn.update!(extraction_status: "processing")
    expect(described_class.new(interview).process!(turn)).to be_nil
    expect(Llm::Fake.calls).to be_empty
  end

  it "writes nothing when a step after the model call fails" do
    Llm::Fake.respond(:extraction) { cafe_output }
    allow_any_instance_of(Interviewing::ArchetypeResolver).to receive(:resolve!).and_raise(RuntimeError, "resolver down")
    runner.answer_and_process!("渋谷でカフェをやっています")

    turn = interview.turns.first.reload
    expect(turn.extraction_status).to eq("failed")
    expect(turn.extraction_error).to include("resolver down")
    expect(Fact.count).to eq(0)
    expect(Goal.count).to eq(0)
    expect(Experience.count).to eq(0)
    expect(site.reload.primary_entity).to be_nil
    expect(turn.answer_text).to eq("渋谷でカフェをやっています"), "the answer itself survives"
  end

  it "reaches ready as soon as the minimum slots of the resolved archetype are filled" do
    Llm::Fake.respond(:extraction) { cafe_output }
    runner.answer_and_process!("渋谷でカフェをやっています")
    expect(interview.reload.status).to eq("ready")
    expect(runner.progress_key).to eq("ready")
  end
end
