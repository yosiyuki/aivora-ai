module Interviewing
  # Interface: next_question(interview) -> Interviewing::Question or nil.
  class QuestionSource
    def next_question(_interview) = raise NotImplementedError
  end
end
