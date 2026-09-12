class AddGenerationClaimToContentItems < ActiveRecord::Migration[8.1]
  def change
    change_table :content_items do |t|
      t.string :generation_token                 # held while status = generating; released by token
      t.string :generation_previous_status       # state to return to if generation fails
    end
  end
end
