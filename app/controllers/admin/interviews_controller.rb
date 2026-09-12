module Admin
  # The setup interview. One question per page, free text only, resumable:
  # GET always shows the latest unanswered question.
  class InterviewsController < ApplicationController
    before_action :load_interview

    def show
      if @interview.completed?
        redirect_to admin_root_path, notice: t("interview.already_completed")
        return
      end
      @runner = Interviewing::Runner.new(@interview)
      @turn = @runner.current_turn
      # No question left and nothing to generate from: nothing useful to show.
      redirect_to admin_root_path, alert: t("interview.nothing_to_ask") if @turn.nil? && !@runner.can_finish?
    end

    def answer
      runner = Interviewing::Runner.new(@interview)
      runner.answer_and_process!(params[:answer], turn_id: params[:turn_id])
      redirect_to admin_interview_path
    rescue Interviewing::Runner::StaleTurn
      redirect_to admin_interview_path, alert: t("interview.stale_turn")
    rescue ArgumentError
      redirect_to admin_interview_path, alert: t("interview.blank_answer")
    end

    def finish
      @interview.complete!
      redirect_to admin_root_path, notice: t("interview.completed")
    rescue Interview::NotFinishable
      redirect_to admin_interview_path, alert: t("interview.not_finishable")
    end

    private

    def load_interview
      @interview = Current.site.current_interview || Current.site.interviews.create!
    end
  end
end
