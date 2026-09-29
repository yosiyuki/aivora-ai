module Admin
  # Emergency Stop, the manual kind (README §34). Freezing stops page
  # generation and nothing else: staleness checks and verification answers
  # keep running, because stopping observation is the one state this product
  # must avoid (§33).
  class AutomationsController < ApplicationController
    def freeze
      Current.site.policy.freeze_automation!
      redirect_to admin_root_path, notice: t("admin.automation.frozen_notice")
    end

    def resume
      Current.site.policy.resume_automation!
      redirect_to admin_root_path, notice: t("admin.automation.resumed_notice")
    end
  end
end
