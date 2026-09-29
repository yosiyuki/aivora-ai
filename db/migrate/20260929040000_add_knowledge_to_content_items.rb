# A per-item page (an article, a Q&A page) is about one knowledge row: an
# Experience or a Question. The row is the page's subject and the source of
# its title and slug, so the link is kept on the item rather than inferred
# from the URL. One page per row per site.
class AddKnowledgeToContentItems < ActiveRecord::Migration[8.1]
  def change
    add_column :content_items, :knowledge_type, :string
    add_column :content_items, :knowledge_id, :bigint
    add_index :content_items, [ :site_id, :knowledge_type, :knowledge_id ], unique: true,
              where: "knowledge_type IS NOT NULL", name: "index_content_items_one_page_per_knowledge"
  end
end
