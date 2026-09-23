module Verification
  # The wording of a verification request, built in code.
  #
  # The model never writes these. A question is the product asking on its own
  # behalf, and a generated one would carry assumptions nothing backs — the
  # same reason page titles are code-generated (Content::Drafter.title_for)
  # and editorial prohibitions are product-fixed.
  module Question
    module_function

    # The slot's label is what the owner sees; the key never is (README §27).
    def for(slot, statement: nil)
      base = I18n.t("verification.question.#{slot.kind}", label: slot.label,
                    default: I18n.t("verification.question.verifiable", label: slot.label))
      statement.present? ? "#{base}\n\n#{I18n.t("verification.question.context", statement: statement)}" : base
    end
  end
end
