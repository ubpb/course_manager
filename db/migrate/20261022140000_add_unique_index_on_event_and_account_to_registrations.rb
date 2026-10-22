class AddUniqueIndexOnEventAndAccountToRegistrations < ActiveRecord::Migration[8.1]

  # An account registers for an event only once. The model validates that, but
  # only the database can stop two requests saving at the same moment.
  # Registrations without an account (ils_primary_id NULL) may still repeat.
  def change
    add_index :registrations, [:event_id, :ils_primary_id], unique: true
  end

end
