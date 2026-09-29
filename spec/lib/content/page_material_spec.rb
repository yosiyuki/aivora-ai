require "rails_helper"

RSpec.describe Content::PageMaterial do
  let!(:site) { cafe_site }   # business

  it "lists the buildable pages of the archetype in its order, top first" do
    expect(described_class.pages_for(site)).to eq(%w[top services faq])
  end

  it "always includes top, even before an archetype is decided" do
    bare = create_site(name: "x", domain: "x.example") rescue Site.current
    bare.site_archetypes.destroy_all
    bare.update!(primary_archetype: nil)

    expect(described_class.pages_for(bare.reload)).to eq(%w[top])
  end

  it "leaves out pages that have no Phase 1 source" do
    site.add_archetype(:media)

    pages = described_class.pages_for(site.reload)

    expect(pages).to include("top", "services", "faq")
    expect(pages).not_to include("news", "articles", "categories", "article")
  end

  it "narrows each page to its own material" do
    services = Content::KnowledgePack.for(site, page_type: "services")
    profile = Content::KnowledgePack.for(site, page_type: "profile")
    faq = Content::KnowledgePack.for(site, page_type: "faq")
    top = Content::KnowledgePack.for(site, page_type: "top")

    expect(services.experiences.map(&:summary)).to eq([ "静かな店内" ]), "what only"
    expect(profile.experiences.map(&:summary)).to contain_exactly("自家焙煎", "静かな店内"), "what and story"
    expect(faq.questions.map(&:text)).to contain_exactly("駐車場はありますか", "予約はできますか")
    expect(top.questions).to be_empty, "top does not print questions"
    expect(services.facts.map(&:slot_key)).not_to include("location")
  end

  it "decides sufficiency from the page's own material, not the site's" do
    expect(Content::KnowledgePack.for(site, page_type: "top")).to be_sufficient
    expect(Content::KnowledgePack.for(site, page_type: "faq")).to be_sufficient
    expect(Content::KnowledgePack.for(site, page_type: "profile")).to be_sufficient
    expect(Content::KnowledgePack.for(site, page_type: "services")).to be_sufficient, "the what experience"
    expect(Content::KnowledgePack.for(site, page_type: "works")).not_to be_sufficient
    expect(Content::KnowledgePack.for(site, page_type: "news")).not_to be_sufficient, "never generated here"
  end
end
