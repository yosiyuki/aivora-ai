require "rails_helper"

RSpec.describe Interviewing::Router do
  let!(:site) { create_site }
  let(:interview) { site.interviews.create! }
  let(:runner) { Interviewing::Runner.new(interview, question_source: Interviewing::FixedQuestionSource.new) }
  let(:turn) { runner.answer!("渋谷でカフェをやっています。豆は農園から直接仕入れて自分で焙煎しています。近所の人にもっと来てほしい。") }

  it "routes intent to goals, facts to Facts, experiences to Experiences — and never intent to Knowledge", :aggregate_failures do
    described_class.new(interview).route!(turn, cafe_output)

    goal = site.goals.sole
    expect(goal.description).to eq("近所の人にもっと来てほしい")
    expect(goal.source_item).to eq(turn.source_item)
    expect(goal.metric).to be_nil, "quantified later by the archetype, never by the model"
    expect(Fact.where("value_json::text LIKE ?", "%来てほしい%")).to be_empty
    expect(Experience.where("body LIKE ?", "%来てほしい%")).to be_empty

    entity = site.reload.primary_entity
    expect(entity).to have_attributes(canonical_name: "渋谷のカフェ", entity_type: "business")
    expect(site.entity_candidates.sole.status).to eq("accepted")

    facts = entity.facts.order(:id)
    expect(facts.map(&:attribute_key)).to eq(%w[location name])
    expect(facts).to all(be_accepted), "the owner said it, so it is accepted with provenance"
    expect(facts.first.evidence.sole.source_item).to eq(turn.source_item)
    expect(facts.first.risk_level).to eq("high")

    experience = site.experiences.sole
    expect(experience.body).to eq("豆は農園から直接仕入れて自分で焙煎しています"), "the owner's words survive verbatim"
    expect(experience).to be_provenanced

    expect(site.questions.sole.text).to include("駐車場")
    expect(interview.reload.slot_state.keys).to contain_exactly("location", "name", "what")
    expect(interview.pending_question["examples"].size).to eq(3)
  end

  it "records the role from the role question only" do
    described_class.new(interview).route!(turn, cafe_output("role" => "business"))
    expect(site.reload.user_role).to eq("business")

    other = runner.answer!("次の答え")
    described_class.new(interview).route!(other, cafe_output("role" => "expert", "primary_entity" => nil, "facts" => [], "experiences" => [], "goals" => [], "utterances" => []))
    expect(site.reload.user_role).to eq("business")
  end

  it "keeps a low-confidence entity as a candidate and stores facts as slot values only" do
    described_class.new(interview).route!(turn, cafe_output("primary_entity" => { "name" => "どこかの店", "entity_type" => "business", "confidence" => 0.3 }))
    expect(site.reload.primary_entity).to be_nil
    expect(site.entity_candidates.sole).to be_pending
    expect(Fact.count).to eq(0)
    expect(interview.reload.slot_state).to include("location")
  end

  it "drops a proposed next question that does not carry exactly three examples" do
    described_class.new(interview).route!(turn, cafe_output("next_question" => { "text" => "x", "examples" => [ "a" ], "targets_slot" => nil, "quotes_user" => false }))
    expect(interview.reload.pending_question).to be_nil
  end
end
