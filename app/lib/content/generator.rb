module Content
  # Pack → draft (LLM) → claims (LLM) → grounding (code) → version, in one
  # transaction, published only if grounding passed. An LLM failure raises
  # before any version exists; a grounding failure is recorded as a version.
  class Generator
    def initialize(site, page_type:, knowledge: nil)
      @site = site
      @page_type = page_type.to_s
      @knowledge = knowledge
    end

    # Returns nil, having called no model, when the page has nothing to be
    # written from yet. The caller leaves the item as it was; answers to
    # verification requests bring the material and the page is tried again.
    def generate!
      started_at = Time.current
      pack = KnowledgePack.for(@site, page_type: @page_type, knowledge: @knowledge)
      return nil unless pack.sufficient?

      draft = Drafter.new(pack).draft
      claims = ClaimExtractor.new(pack).extract(draft.body)
      result = Grounder.new(pack).ground(body: draft.body, claims: claims)

      ContentItem.transaction do
        url = @knowledge ? ContentItem.url_for_knowledge(@page_type, @knowledge) : ContentItem.url_for(@page_type)
        item = @site.content_items.find_or_create_by!(url: url) do |i|
          i.archetype_page_type = @page_type
          i.content_type = @knowledge ? "article" : "page"
          i.knowledge = @knowledge
        end
        # Created pending, claims written, then decided: after decide! the
        # version and its claims are frozen.
        version = item.append_version!(
          title: draft.title, body: result.body,
          source: item.versions.exists? ? "regenerated" : "generated",
          metadata: {
            "pack" => { "facts" => pack.facts.map(&:id), "experiences" => pack.experiences.map(&:id), "truncated" => pack.truncated },
            "blanks" => result.blanks, "notes" => result.notes,
            "llm_usage_ids" => LlmUsage.where(site: @site).where("created_at >= ?", started_at).pluck(:id)
          }
        )
        result.claims.each { |attrs| version.claims.create!(attrs) }
        version.decide!(result.status)
        item.publish!(version) if result.status == :passed
        version
      end
    end
  end
end
