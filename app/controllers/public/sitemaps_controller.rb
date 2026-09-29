# /sitemap.xml: every published page, so search engines learn the site's
# shape from the site rather than by crawling. Rendered on request like every
# other public page (Technical Architecture §45: nothing is written to disk).
module Public
  class SitemapsController < ApplicationController
    allow_unauthenticated_access

    def show
      site = Current.site
      items = site ? site.content_items.published.includes(:published_version).order(:id).to_a : []
      return unless stale?(etag: [ "sitemap", items.map { |i| [ i.id, i.published_version_id ] } ], public: true)

      render xml: build(items), content_type: "application/xml"
    end

    private

    # Absolute URLs use the host that actually served the request, not
    # Site#domain: while a site is being tried out on a PaaS hostname the two
    # differ, and a sitemap pointing elsewhere is worse than none.
    def build(items)
      Nokogiri::XML::Builder.new(encoding: "UTF-8") do |xml|
        xml.urlset(xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9") do
          items.each do |item|
            xml.url do
              xml.loc "#{request.base_url}#{item.url}"
              xml.lastmod item.published_version.created_at.utc.iso8601
            end
          end
        end
      end.to_xml
    end
  end
end
