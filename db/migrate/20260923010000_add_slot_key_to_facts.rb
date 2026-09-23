# Which archetype slot a fact fills, when it fills one (README §28).
#
# attribute_key stays the free-text label the extraction produced; it is what
# supersede! carries forward and what the Knowledge Pack prints. slot_key is
# the separate, product-fixed vocabulary that decides whether a required slot
# is satisfied. Facts that answer no slot keep it null.
class AddSlotKeyToFacts < ActiveRecord::Migration[8.1]
  def change
    add_column :facts, :slot_key, :string
    add_index :facts, [ :site_id, :slot_key ]
  end
end
