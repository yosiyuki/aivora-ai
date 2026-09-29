module Content
  # The list pages (記事一覧), built in code from the pages they list. No model
  # is called and no claim is made: a list of the site's own published pages
  # is navigation, the same kind of thing as Public::Navigation, so it is
  # published straight away with source "listed".
  module Lister
    LISTS = { "articles" => "article" }.freeze

    module_function

    def refresh!(site)
      LISTS.each do |list_type, item_type|
        next unless PageMaterial.structure(site).include?(list_type)

        publish_list!(site, list_type, item_type)
      end
    end

    def publish_list!(site, list_type, item_type)
      items = site.content_items.published.where(archetype_page_type: item_type).order(published_at: :desc, id: :desc)
      return if items.empty?   # a list of nothing is not a page

      body = render(list_type, items)
      list = site.content_items.find_or_create_by!(url: ContentItem.url_for(list_type)) do |i|
        i.archetype_page_type = list_type
        i.content_type = "page"
      end
      return list.published_version if list.published_version&.body == body   # nothing changed

      ContentItem.transaction do
        version = list.append_version!(title: title_for(list_type), body: body, source: "listed",
                                       metadata: { "listed" => items.map(&:id) })
        version.decide!(:passed)
        list.publish!(version)
        version
      end
    end

    def render(list_type, items)
      lines = [ "# #{title_for(list_type)}", "" ]
      lines.concat(items.map { |i| "- [#{i.title}](#{i.url})" })
      lines.join("\n") + "\n"
    end

    def title_for(list_type) = Drafter::PAGE_TITLES.fetch(list_type).call(nil)
  end
end
