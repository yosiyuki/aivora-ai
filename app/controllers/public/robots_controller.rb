# robots.txt rendered on request rather than served from public/, because the
# Sitemap line needs the host that is actually serving the site. A static file
# under public/ would win over this route, so there must not be one.
module Public
  class RobotsController < ApplicationController
    allow_unauthenticated_access

    def show
      render plain: <<~ROBOTS, content_type: "text/plain"
        User-agent: *
        Disallow: /admin
        Disallow: /setup
        Disallow: /session

        Sitemap: #{request.base_url}/sitemap.xml
      ROBOTS
    end
  end
end
