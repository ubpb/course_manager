class RemoveRedundantEventIdIndexFromRegistrations < ActiveRecord::Migration[8.1]

  # The unique index on (event_id, ils_primary_id) starts with event_id, so it
  # serves every lookup by event_id -- and the foreign key to events -- as well.
  def change
    remove_index :registrations, :event_id, name: "index_registrations_on_event_id"
  end

end
