module Content
  # Second LLM call per page: extract and classify the claims in a draft. It
  # never rewrites the draft and never decides grounding — that is Grounder.
  class ClaimExtractor
    PROMPT_DIR = Rails.root.join("app/prompts/content")

    def initialize(pack, client: Llm::Client.for(:grounding))
      @pack = pack
      @client = client
    end

    def extract(body)
      output = @client.extract(system: system_prompt, input: input_for(body),
                               schema: ClaimSchema.build(slot_keys: @pack.slot_keys), related: @pack.site)
      Array(output["claims"]).select { |c| c.is_a?(Hash) && c["statement"].present? }
    end

    def system_prompt
      PROMPT_DIR.join("grounding.txt").read.sub("{{EDITORIAL_POLICY}}", PROMPT_DIR.join("editorial_policy.txt").read)
    end

    private

    def input_for(body)
      refs = @pack.facts.map { |f| "#{f.ref}: #{f.attribute_key} = #{f.value}" } +
             @pack.experiences.map { |e| "#{e.ref}: #{e.summary}" }
      "# 材料一覧\n#{refs.join("\n").presence || "（なし）"}\n\n# 本文\n#{body}"
    end
  end
end
