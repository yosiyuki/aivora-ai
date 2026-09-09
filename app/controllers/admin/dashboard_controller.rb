module Admin
  # Landing page after login. The review/observation surface grows here; for
  # now it confirms setup and points at the next step (the interview, #3).
  class DashboardController < ApplicationController
    def show
      @site = Current.site
    end
  end
end
