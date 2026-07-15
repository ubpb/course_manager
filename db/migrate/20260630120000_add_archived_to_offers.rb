class AddArchivedToOffers < ActiveRecord::Migration[8.1]
  def change
    add_column :offers, :archived, :boolean, default: false, null: false
    add_index :offers, :archived
  end
end
