require "rails_helper"

# README §23: nothing is physically deleted. With no per-action human review,
# an irreversible operation cannot exist in the system — that is what makes
# autonomous operation recoverable.
RSpec.describe NeverDeleted do
  let!(:site) { cafe_site }

  # Every model that holds knowledge, provenance, published content, or the
  # record of asking the owner something.
  MODELS = [
    Fact, Claim, Entity, EntityAlias, EntityCandidate, Experience, Question, Problem,
    Evidence, EvidenceLink, KnowledgeVersion, Goal,
    ContentItem, ContentVersion, ContentClaim, VerificationRequest, VerificationEvent
  ].freeze

  it "is included by every model that must not lose rows" do
    missing = MODELS.reject { |m| m.include?(described_class) }

    expect(missing).to be_empty, "these can still be destroyed: #{missing.join(', ')}"
  end

  it "refuses destroy with a message naming the model" do
    # A goal has no dependents at all, so nothing else can be mistaken for the
    # guard: this is NeverDeleted refusing on its own.
    goal = site.goals.first

    expect { goal.destroy! }
      .to raise_error(ActiveRecord::RecordNotDestroyed, /Goal rows are never physically deleted/)
  end

  it "does not touch tables that are meant to churn" do
    # Solid Queue deletes its own rows constantly; sessions end; a site's
    # archetypes and policy are configuration, not history.
    [ Session, SiteArchetype, SitePolicy, Source, SourceItem, Interview, InterviewTurn, LlmUsage ]
      .each { |m| expect(m.include?(described_class)).to be(false), "#{m} should stay deletable" }
  end

  it "leaves a knowledge row standing when its entity is taken away" do
    entity = site.primary_entity

    # nullify would have stripped the subject from these rows while keeping
    # them, losing information without recording that anything happened.
    expect { entity.destroy! }.to raise_error(ActiveRecord::ActiveRecordError)
    expect(site.experiences.where(entity_id: entity.id).count).to be >= 1
    expect(site.facts.where(entity_id: entity.id).count).to be >= 1
  end

  it "keeps provenance when the knowledge it backs is attacked" do
    fact = site.facts.for_slot("location").first
    link_count = fact.evidence_links.count

    expect { fact.destroy! }.to raise_error(ActiveRecord::ActiveRecordError)
    expect(fact.reload.evidence_links.count).to eq(link_count)
  end
end
