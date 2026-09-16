# Serves the pages this site has published (issue #6, Technical Architecture §22).
#
# The site is its own output CMS: pages are rendered from the stored version on
# request, not exported to a file or pushed to another system.
module Public
  class PagesController < ApplicationController
    allow_unauthenticated_access
    layout "public"

    def show
      @site = Current.site
      return render_missing if @site.nil?

      @item = @site.content_items.published.includes(:published_version).find_by(url: requested_url)
      return render_missing if @item.nil?

      @version = @item.published_version
      @navigation = Public::Navigation.for(@site)
      fresh_when(@version, public: true)
    end

    private

    # The lookup key is the URL exactly as it was issued (ContentItem#url).
    # Only a trailing slash is forgiven, because "/articles/" and "/articles"
    # are the same page to a visitor and neither form can be issued twice.
    def requested_url
      path = "/#{params[:path]}"
      path.length > 1 ? path.chomp("/") : path
    end

    def render_missing
      render "public/pages/not_found", status: :not_found, formats: :html
    end
  end
end
