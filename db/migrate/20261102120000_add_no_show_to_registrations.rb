class AddNoShowToRegistrations < ActiveRecord::Migration[8.1]

  # Participants who registered but did not attend get no certificate.
  def change
    add_column :registrations, :no_show, :boolean, default: false, null: false
  end

end
