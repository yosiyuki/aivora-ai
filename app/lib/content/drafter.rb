module Content
  # First of the two LLM calls per page: free-text Markdown written only from
  # the knowledge pack, with [[slot:key]] where a verifiable fact is missing.
  class Drafter
    PROMPT_DIR = Rails.root.join("app/prompts/content")
    PAGE_TYPE_GUIDES = {
      "top" => "訪問者が最初に読む紹介ページ。何をしているか、誰のためか、どこにあるか、本人ならではの点を、この順で。",
      "services" => "提供しているものの一覧と、それぞれの短い説明。",
      "faq" => "よく聞かれることへの答え。質問を小見出しにする。",
      "news" => "最近のお知らせ。日付が材料に無ければ日付を書かない。",
      "articles" => "書いた記事の一覧ページ。",
      "article" => "1 つのテーマを掘り下げる記事。",
      "topics" => "扱うトピックの一覧。",
      "question" => "1 つの疑問への答え。",
      "works" => "代表的な実績の紹介。",
      "profile" => "本人の紹介。"
    }.freeze
    LENGTHS = { "top" => "600〜1200 字", "article" => "1200〜2500 字" }.freeze
    Draft = Data.define(:title, :body)

    def initialize(pack, client: Llm::Client.for(:drafting))
      @pack = pack
      @client = client
    end

    def draft
      text = @client.generate(system: system_prompt, messages: [ { role: :user, content: user_prompt } ], related: @pack.site)
      parse(text)
    end

    def system_prompt
      PROMPT_DIR.join("draft.txt").read
        .sub("{{PAGE_TYPE_GUIDE}}", PAGE_TYPE_GUIDES.fetch(@pack.page_type, PAGE_TYPE_GUIDES["article"]))
        .sub("{{LENGTH}}", LENGTHS.fetch(@pack.page_type, "800〜1500 字"))
        .sub("{{EDITORIAL_POLICY}}", PROMPT_DIR.join("editorial_policy.txt").read)
    end

    private

    def user_prompt = "# 材料\n#{@pack.to_prompt}\n\n# 指示\n上の材料だけで、#{@pack.page_type} ページを書いてください。"

    PAGE_TITLES = {
      "top" => ->(name) { name },
      "services" => ->(name) { "#{name}のサービス" },
      "faq" => ->(_) { "よくある質問" },
      "news" => ->(_) { "お知らせ" },
      "articles" => ->(_) { "記事一覧" },
      "topics" => ->(_) { "トピック" },
      "works" => ->(name) { "#{name}の実績" },
      "profile" => ->(name) { "#{name}について" }
    }.freeze

    # The model's title is never used: it is not grounded, and it goes into
    # the public <title>. Titles are generated in code from the subject name.
    def self.title_for(pack)
      name = pack.entity&.canonical_name.presence || pack.site.name
      PAGE_TITLES.fetch(pack.page_type, ->(n) { n }).call(name)
    end

    def parse(text)
      lines = text.to_s.strip.lines
      title_line = lines.find { |l| l.start_with?("# ") }
      body = lines.reject { |l| l.equal?(title_line) }.join.strip
      Draft.new(title: self.class.title_for(@pack), body: body)
    end
  end
end
