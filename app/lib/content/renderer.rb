module Content
  # Markdown → sanitised HTML for both the admin preview and the public
  # pages (#6). Blanks ([[slot:key]]) render as a visible "確認中" mark.
  module Renderer
    ALLOWED_TAGS = %w[h1 h2 h3 h4 p br strong em ul ol li a blockquote code pre hr span].freeze
    ALLOWED_ATTRIBUTES = %w[href class data-slot].freeze
    BLANK_HTML = '<span class="blank" data-slot="%s">（確認中）</span>'

    module_function

    def render(markdown)
      html = Commonmarker.to_html(markdown.to_s, options: { render: { unsafe: false, hardbreaks: false }, extension: { autolink: true } })
      html = html.gsub(ContentVersion::BLANK_PATTERN) { format(BLANK_HTML, ERB::Util.html_escape(Regexp.last_match(1))) }
      Rails::HTML5::SafeListSanitizer.new.sanitize(html, tags: ALLOWED_TAGS, attributes: ALLOWED_ATTRIBUTES).html_safe
    end
  end
end
