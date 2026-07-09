class AddEventsOnRequestToOffers < ActiveRecord::Migration[8.1]
  def change
    add_column :offers, :events_on_request, :boolean, default: false, null: false
  end
end
