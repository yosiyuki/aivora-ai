module Content
  # Aggregate Policy for generation volume (README §32): one page is safe, many
  # at once is not. With no per-action approval this and Emergency Stop are the
  # only safety mechanisms, so the defaults are conservative.
  #
  # Counted in versions, not items: an item row can exist before any page does
  # (it is created when generation is claimed), so "a new page" is the first
  # version and "a change" is any later one. Windows are the site's own week
  # and day, the same way Llm::Budget takes the site's month.
  #
  # Reaching a cap defers, it never stops: the job simply does nothing, and
  # the next window picks the work up again. Same spirit as degrade (§33).
  class Throttle
    def self.for(site)
      Current.content_throttles ||= {}
      Current.content_throttles[site.id] ||= new(site)
    end

    def initialize(site)
      @site = site
    end

    def new_page_allowed? = new_pages_this_week < policy.new_pages_per_week_cap
    def change_allowed? = changes_today < policy.pages_changed_per_day_cap

    def new_pages_this_week = @new_pages_this_week ||= versions.where(version: 1, created_at: week).count
    def changes_today = @changes_today ||= versions.where("content_versions.version > 1").where(created_at: day).count

    def new_pages_capped? = !new_page_allowed?
    def changes_capped? = !change_allowed?

    # Which of the two a given generation counts as: a page that has no version
    # yet is new; anything else is a change.
    def allowed_for?(page_type)
      item = @site.content_items.find_by(url: ContentItem.url_for(page_type))
      item.nil? || item.versions.none? ? new_page_allowed? : change_allowed?
    end

    def week = Time.use_zone(@site.timezone) { Time.current.all_week }
    def day = Time.use_zone(@site.timezone) { Time.current.all_day }

    private

    def policy = @policy ||= @site.policy
    def versions = ContentVersion.joins(:content_item).where(content_items: { site_id: @site.id })
  end
end
