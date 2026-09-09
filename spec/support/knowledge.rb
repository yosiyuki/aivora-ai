module KnowledgeHelper
  def owner_source_item(site = Site.current, text: "朝7時に開けています")
    Source.interview_for(site).source_items.create!(raw_content: text, external_id: SecureRandom.hex(4))
  end

  def owner_evidence(site = Site.current, text: "朝7時に開けています")
    Evidence.from_source_item!(owner_source_item(site, text: text), content: text)
  end
end

RSpec.configure { |c| c.include KnowledgeHelper }
