require "rails_helper"

RSpec.describe KnowledgeVersion, type: :model do
  let!(:site) { cafe_site }
  let(:fact) { site.facts.for_slot("location").first }

  it "is written by the knowledge it describes, one per change" do
    expect(fact.knowledge_versions.count).to be >= 1

    fact.update!(confidence: 0.95)

    expect(fact.knowledge_versions.count).to be >= 2
    expect(fact.knowledge_versions.last.snapshot["confidence"]).to eq(0.95)
  end

  it "cannot be rewritten: a snapshot records what was true then" do
    version = fact.knowledge_versions.first

    expect(version).to be_readonly
    expect { version.update!(change_reason: "書き換え") }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  it "cannot be deleted" do
    version = fact.knowledge_versions.first

    expect { version.destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed)
  end

  it "keeps its knowledge undeletable even when the versions are attacked first" do
    # The old guarantee was conditional: a fact was undeletable only because it
    # had versions, so removing them first made the fact deletable again.
    expect { KnowledgeVersion.where(knowledge: fact).find_each(&:destroy!) }
      .to raise_error(ActiveRecord::RecordNotDestroyed)

    # Both doors are shut: the versions survive, so the fact is still held by
    # its dependents, and NeverDeleted would refuse it even if they were gone.
    expect(KnowledgeVersion.where(knowledge: fact).count).to be >= 1
    expect { Fact.find(fact.id).destroy! }.to raise_error(ActiveRecord::ActiveRecordError)
  end
end
