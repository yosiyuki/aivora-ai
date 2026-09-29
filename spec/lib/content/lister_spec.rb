require "rails_helper"

RSpec.describe Content::Lister do
  let!(:site) { cafe_site.tap { |s| s.add_archetype(:media) }.reload }

  def article!(experience)
    stub_article_generation(experience)
    Content::GenerateJob.perform_now(site.id, "article", "Experience", experience.id)
    site.content_items.find_by!(knowledge: experience)
  end

  it "publishes a list of the published articles without calling a model" do
    first = article!(site.experiences.first)
    Llm::Fake.reset!

    described_class.refresh!(site)

    list = site.content_items.find_by!(url: "/articles")
    expect(list).to be_published
    expect(list.published_version.source).to eq("listed")
    expect(list.published_version.body).to include("[#{first.title}](#{first.url})")
    expect(list.published_version.claims).to be_empty
    expect(Llm::Fake.calls).to be_empty
  end

  it "is refreshed when an article is published, and not rewritten when nothing changed" do
    article!(site.experiences.first)
    list = site.content_items.find_by!(url: "/articles")
    versions = list.versions.count

    described_class.refresh!(site)

    expect(list.reload.versions.count).to eq(versions), "same body, no new version"

    article!(site.experiences.second)

    expect(list.reload.versions.count).to eq(versions + 1)
    expect(list.published_version.body.scan("](/article/").size).to eq(2)
  end

  it "makes no list page while there is nothing to list" do
    described_class.refresh!(site)

    expect(site.content_items.find_by(url: "/articles")).to be_nil
  end

  it "does nothing on a site whose structure has no article list" do
    business = cafe_site
    business.site_archetypes.where(archetype: "media").destroy_all

    described_class.refresh!(business.reload)

    expect(business.content_items.find_by(url: "/articles")).to be_nil
  end
end
