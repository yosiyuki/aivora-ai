module Knowledge
  # How much of what this site needs to know it actually knows, and how much of
  # that is still trustworthy (README §8). The one indicator that works before
  # any input source is connected, which is why it is the launch-phase headline.
  #
  # The score is a weighted average over the archetype's required slots
  # (README §28, DatabaseSchema §65: `weight` is the Knowledge Health input).
  # Everything here is arithmetic on rows the system already keeps; no model is
  # consulted, and the formula changes only by changing this file.
  class Health
    # A slot is worth its full weight while a fresh, accepted fact answers it;
    # half while the answer has gone stale or two answers disagree; nothing
    # while there is no answer at all. An open question about it does not move
    # the number — the missing fact already does.
    STATE_SCORE = { fresh: 1.0, stale: 0.5, conflicting: 0.5, missing: 0.0 }.freeze

    Slot = Data.define(:key, :label, :level, :kind, :weight, :state)

    def self.for(site) = new(site)

    def initialize(site)
      @site = site
    end

    # 0..100, or nil before an archetype has been decided (no slots to score).
    def score
      slots = by_slot
      return nil if slots.empty?

      total = slots.sum(&:weight)
      return nil if total.zero?

      (slots.sum { |s| s.weight * STATE_SCORE.fetch(s.state) } / total * 100).round
    end

    def by_slot
      @by_slot ||= @site.required_slots.map do |slot|
        Slot.new(key: slot.key, label: slot.label, level: slot.level, kind: slot.kind, weight: slot.weight,
                 state: state_for(slot))
      end
    end

    # --- the six counts README §8 lists ---------------------------------------

    def fresh_facts = accepted.count { |f| !Verification::Staleness.stale?(f) }

    # Marked stale by the nightly sweep, or past its window and not yet swept.
    def stale_facts = @site.facts.where(status: "stale").count + accepted.count { |f| Verification::Staleness.stale?(f) }

    # Two accepted answers to the same slot of the same subject.
    def conflicting_facts
      @site.facts.where(status: "accepted").where.not(slot_key: nil)
           .group(:entity_id, :slot_key).having("count(*) > 1").count.values.sum
    end

    # Blanks the reader can see: 「（確認中）」 on a published page.
    def unverified_claims
      ContentClaim.blanks
                  .joins(content_version: :content_item)
                  .where(content_items: { site_id: @site.id, status: "published" })
                  .where("content_versions.id = content_items.published_version_id")
                  .count
    end

    # Extracted but never backed by the owner's words. An accepted fact always
    # has evidence (the model refuses otherwise), so the gap lives in candidates.
    def missing_evidence = @site.facts.where(status: "candidate").count

    def open_requests = @site.verification_requests.open.count

    private

    def accepted = @accepted ||= @site.facts.where(status: "accepted").to_a

    def facts_by_slot = @facts_by_slot ||= @site.facts.where(status: %w[accepted stale]).where.not(slot_key: nil).group_by(&:slot_key)

    def interview_filled = @interview_filled ||= @site.current_interview&.filled_slot_keys.to_a

    # Facts carry the slot (since #36); older knowledge and experiential slots
    # are known filled through the interview's own record, which is the owner's
    # word and does not expire.
    def state_for(slot)
      facts = facts_by_slot.fetch(slot.key, [])
      if facts.any?
        fresh = facts.select { |f| f.status == "accepted" && !Verification::Staleness.stale?(f) }
        return :conflicting if fresh.size > 1
        return :fresh if fresh.size == 1

        :stale
      elsif interview_filled.include?(slot.key)
        :fresh
      else
        :missing
      end
    end
  end
end
