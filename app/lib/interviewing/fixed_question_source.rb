module Interviewing
  # Questions that need no LLM: the fixed opening three (role, topic,
  # purpose) and generic follow-ups. #15 replaces the follow-ups with
  # questions that quote the user's own words; the opening three stay.
  class FixedQuestionSource < QuestionSource
    OPENING = [
      Question.new(kind: "role", text: "あなたの役割を教えてください。",
                   examples: [ "カフェの店主です",
                               "会社で広報を担当していますが、専門ではありません",
                               "個人で活動していて、自分のことを知ってもらう場所がほしいと思っています" ]),
      Question.new(kind: "topic", text: "何について発信しますか？",
                   examples: [ "自分の店のこと",
                               "渋谷でカフェをやっています。自家焙煎の豆にこだわっています",
                               "機械学習を独学していて、詰まったところや解決した方法をメモとして残したいです。同じところで困っている人の役に立てばと思っています" ]),
      Question.new(kind: "purpose", text: "このサイトを見た人に、どうなってほしいですか？",
                   examples: [ "お店に来てほしい",
                               "内容を読んで、こういう考え方もあるんだと知ってほしい",
                               "常連さんが増えなくて、新しい人にも来てほしい。でも観光客ばかりだと雰囲気が変わってしまうので、近所の人に知ってもらいたい" ])
    ].freeze

    FOLLOW_UPS = [
      Question.new(kind: "open", text: "いちばん伝えたいことを、もう少し聞かせてください。",
                   examples: [ "豆の焙煎にこだわっています",
                               "静かで、一人でも長居しやすい雰囲気にしています",
                               "10年前に脱サラして始めました。最初は誰も来なかったけれど、近所の方が少しずつ常連になってくれて、今はその人たちのために続けているところがあります" ]),
      Question.new(kind: "open", text: "来てくれた人や読んでくれた人から、よく聞かれることはありますか？",
                   examples: [ "駐車場はあるか",
                               "初心者でも大丈夫か、どこから始めればいいか",
                               "「あの豆はどこで買えるの」とよく聞かれます。実は店でも売っているのですが、ほとんどの人が気づいていません" ]),
      Question.new(kind: "open", text: "これは書きたくない、触れたくない、という話はありますか？",
                   examples: [ "特にありません",
                               "値段の話はあまり前に出したくない",
                               "以前やっていた別の事業のことは書かないでほしい。今の店とは関係ないので" ])
    ].freeze

    def next_question(interview)
      asked = interview.turns.size
      return OPENING[asked] if asked < OPENING.size

      FOLLOW_UPS[(asked - OPENING.size) % FOLLOW_UPS.size]
    end
  end
end
