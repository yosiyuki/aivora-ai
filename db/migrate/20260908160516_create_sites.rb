class CreateSites < ActiveRecord::Migration[8.1]
  def change
    create_table :sites do |t|
      t.string :name, null: false
      t.string :domain, null: false
      t.string :primary_language, null: false, default: "ja"
      t.string :timezone, null: false, default: "Asia/Tokyo"
      t.string :user_role          # set by the interview (#3): expert / business / individual
      t.string :primary_archetype  # derived from the goal (#3): business / media / knowledge_base / portfolio
      t.string :status, null: false, default: "setup"

      t.timestamps
    end
  end
end
