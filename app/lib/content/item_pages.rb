module Content
  # Which per-item pages a site is owed: one per Experience (article) or per
  # Question (question page), for the item types its structure names, minus
  # the ones that already have a page. Called after the interview and after
  # every verification answer, so new knowledge becomes a page without anyone
  # deciding that it should.
  module ItemPages
    module_function

    def enqueue_pending(site)
      pending(site).each do |page_type, row|
        GenerateJob.perform_later(site.id, page_type, row.class.name, row.id)
      end
    end

    def pending(site)
      PageMaterial.item_page_types_for(site).flat_map do |page_type|
        klass = PageMaterial.subject_class(page_type)
        covered = site.content_items.where(knowledge_type: klass.name).pluck(:knowledge_id)
        klass.where(site: site).where.not(id: covered).order(:id).map { |row| [ page_type, row ] }
      end
    end
  end
end
