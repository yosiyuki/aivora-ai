module InterviewFixtures
  # A complete, schema-shaped Extraction Agent output for "渋谷でカフェ".
  def cafe_output(overrides = {})
    {
      "role" => nil,
      "utterances" => [
        { "text" => "渋谷でカフェをやっています", "kind" => "fact", "confidence" => 0.95 },
        { "text" => "豆は農園から直接仕入れて自分で焙煎しています", "kind" => "experience", "confidence" => 0.9 },
        { "text" => "近所の人にもっと来てほしい", "kind" => "intent", "confidence" => 0.9 },
        { "text" => "駐車場はあるかとよく聞かれます", "kind" => "question", "confidence" => 0.8 }
      ],
      "primary_entity" => { "name" => "渋谷のカフェ", "entity_type" => "business", "confidence" => 0.9 },
      "facts" => [ { "slot" => "location", "attribute" => "location", "value" => "渋谷", "confidence" => 0.9 },
                   { "slot" => "name", "attribute" => "name", "value" => "渋谷のカフェ", "confidence" => 0.85 } ],
      "experiences" => [ { "slot" => "what", "summary" => "自家焙煎のコーヒー", "quote" => "豆は農園から直接仕入れて自分で焙煎しています", "confidence" => 0.9 } ],
      "goals" => [ { "statement" => "近所の人にもっと来てほしい", "verb" => "来てほしい", "confidence" => 0.9 } ],
      "archetype" => { "candidates" => [ { "archetype" => "business", "confidence" => 0.9 }, { "archetype" => "media", "confidence" => 0.3 } ] },
      "next_question" => { "text" => "「農園から直接」というところ、もう少し聞かせてください。", "examples" => [ "友人の紹介です", "コロンビアの農園と契約しています", "10年前に旅行で訪れた農園で、それ以来ずっと同じ人から買っています" ],
                           "targets_slot" => "story", "quotes_user" => true }
    }.deep_merge(overrides)
  end
end

RSpec.configure { |c| c.include InterviewFixtures }
