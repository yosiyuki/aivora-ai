module Admin
  # Landing page after login. The review/observation surface grows here; for
  # now it confirms setup and points at the next step (the interview, #3).
  class DashboardController < ApplicationController
    def show
      @site = Current.site
      @top_page = @site.top_page
      @usage = Llm::Usage::Report.for(@site)
      @throttle = Content::Throttle.for(@site)
      @policy = @site.policy
    end
  end
end
