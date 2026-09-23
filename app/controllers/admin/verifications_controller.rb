module Admin
  # The owner answers the questions the site could not answer itself.
  #
  # This is the only place after setup where the owner types anything. It is
  # not an editing surface: the answer becomes Knowledge and the page is
  # rebuilt from it, so the text of a page is still never hand-written.
  class VerificationsController < ApplicationController
    def index
      @requests = Current.site.verification_requests.open.by_priority.includes(:content_claim)
    end

    def answer
      request = Current.site.verification_requests.open.find(params[:id])
      text = params[:answer].to_s.strip

      if text.blank?
        redirect_to admin_verifications_path, alert: t("verification.blank_answer") and return
      end

      event = request.record_answer!(text, person_id: VerificationEvent.person_id_for(Current.user))
      Verification::ProcessAnswersJob.perform_later(event.id)
      redirect_to admin_verifications_path, notice: t("verification.thanks")
    end

    def skip
      request = Current.site.verification_requests.open.find(params[:id])
      request.events.create!(person_id: VerificationEvent.person_id_for(Current.user), result: "skipped",
                             verified_at: Time.current, extraction_status: "done")
      request.close!
      redirect_to admin_verifications_path, notice: t("verification.skipped")
    end
  end
end
