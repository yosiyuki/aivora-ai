module Admin
  # Observation surface for generated pages: what exists, which version is
  # published, what failed, and which blanks remain. No editing.
  class ContentItemsController < ApplicationController
    before_action :load_item, only: %i[show regenerate]

    def index
      @items = Current.site.content_items.includes(:published_version, :latest_version).order(:created_at)
    end

    def show
      @versions = @item.versions.includes(:claims).reverse
      @published = @item.published_version
      @blank_labels = blank_labels(@published || @item.latest_version)
    end

    def regenerate
      if @item.generating?
        redirect_to admin_content_item_path(@item), alert: t("content.already_generating")
      else
        Content::GenerateJob.perform_later(Current.site.id, @item.archetype_page_type)
        redirect_to admin_content_item_path(@item), notice: t("content.regenerate_queued")
      end
    end

    private

    def load_item
      @item = Current.site.content_items.find(params[:id])
    end

    # Slot keys are internal; the user sees the archetype's label.
    def blank_labels(version)
      return [] unless version

      keys = version.blank_slot_keys | version.claims.blanks.pluck(:slot_key).compact
      slots = Current.site.required_slots.index_by(&:key)
      keys.map { |k| slots[k]&.label || t("content.unknown_blank") }.uniq
    end
  end
end
