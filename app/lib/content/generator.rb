module Content
  # Pack → draft (LLM) → claims (LLM) → grounding (code) → version, in one
  # transaction, published only if grounding passed. An LLM failure raises
  # before any version exists; a grounding failure is recorded as a version.
  class Generator
    def initialize(site, page_type:)
      @site = site
      @page_type = page_type.to_s
    end

    def generate!
      started_at = Time.current
      pack = KnowledgePack.for(@site, page_type: @page_type)
      draft = Drafter.new(pack).draft
      claims = ClaimExtractor.new(pack).extract(draft.body)
      result = Grounder.new(pack).ground(body: draft.body, claims: claims)

      ContentItem.transaction do
        item = @site.content_items.find_or_create_by!(url: ContentItem.url_for(@page_type)) do |i|
          i.archetype_page_type = @page_type
          i.content_type = "page"
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
