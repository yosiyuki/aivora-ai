require "rails_helper"

RSpec.describe Interviewing::Runner do
  let!(:site) { create_site }
  let(:interview) { site.interviews.create! }
  let(:runner) { described_class.new(interview) }

  it "opens with the fixed role question and three examples of differing length" do
    turn = runner.current_turn
    expect(turn.question_kind).to eq("role")
    expect(turn.question_text).to include("役割")
    expect(turn.examples.size).to eq(3)
    expect(turn.examples.map(&:length).uniq.size).to eq(3)
  end

  it "records an answer as conversational state and as owner-trusted raw input" do
    turn = runner.answer!("  渋谷でカフェをやっています  ")
    expect(turn.answer_text).to eq("渋谷でカフェをやっています")
    expect(turn).to be_answered

    item = turn.source_item
    expect(item.raw_content).to eq("渋谷でカフェをやっています")
    expect(item.source.source_type).to eq("interview")
    expect(item).to be_owner
    expect(item.metadata).to include("question_kind" => "role", "turn_id" => turn.id)
    expect(interview.reload.question_count).to eq(1)
  end

  it "shows the same unanswered question again on resume" do
    first = runner.current_turn
    expect(described_class.new(Interview.find(interview.id)).current_turn).to eq(first)
    runner.answer!("店主です")
    second = runner.current_turn
    expect(second.position).to eq(2)
    expect(second.question_kind).to eq("topic")
  end

  it "rejects blank answers and unanswered double submits" do
    expect { runner.answer!("   ") }.to raise_error(ArgumentError, /blank/)
    expect(interview.reload.question_count).to eq(0)
  end

  it "stops handing out questions at the cap and offers to generate" do
    9.times { |i| runner.answer!("答え #{i}") }
    expect(runner.progress_key).to eq("collecting")
    expect(runner).to be_can_finish
    runner.answer!("10 個目")
    expect(interview.reload).to be_capped
    expect(runner.progress_key).to eq("capped")
    expect(runner.current_turn).to be_nil
  end

  it "marks the interview ready as soon as minimum slots are filled" do
    site.add_archetype(:portfolio, primary: true)
    runner.answer!("デザイナーです")
    interview.fill_slot!(:name, value: "山田")
    expect(runner.progress_key).to eq("almost"), "one minimum slot left"
    interview.fill_slot!(:what, value: "ロゴデザイン")
    runner.answer!("実績を見てもらいたい")
    expect(interview.reload.status).to eq("ready")
    expect(runner.progress_key).to eq("ready")
  end
end
