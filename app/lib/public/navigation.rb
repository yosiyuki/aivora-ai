# The public navigation, derived from the site's archetypes (README §28).
#
# Structure comes from the goal: the archetype definitions fix `page_structure`
# and this only filters it down to the pages that actually exist and are
# published. Adding an archetype therefore adds entries; it never moves or
# removes an existing URL (Technical Architecture §23).
module Public
  module Navigation
    Entry = Data.define(:page_type, :label, :url)

    module_function

    def for(site)
      return [] if site.nil?

      published = site.content_items.published.index_by(&:archetype_page_type)
      page_types(site).filter_map do |page_type|
        item = published[page_type]
        Entry.new(page_type: page_type, label: label_for(page_type), url: item.url) if item
      end
    end

    # Primary archetype first, then the order each definition declares.
    def page_types(site)
      site.archetype_definitions.flat_map(&:page_structure).uniq
    end

    # Users never see a page type key, the same rule that hides slot keys and
    # the word "archetype" itself (README §27).
    def label_for(page_type)
      I18n.t(page_type, scope: "page_types", default: page_type.to_s)
    end
  end
end
