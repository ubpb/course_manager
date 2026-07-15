class AddIlsPrimaryIdToRegistrations < ActiveRecord::Migration[8.1]

  def change
    add_column :registrations, :ils_primary_id, :string
    add_index :registrations, :ils_primary_id
  end

end
