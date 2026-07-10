class AddCallToActionToOffer < ActiveRecord::Migration[8.1]

  def change
    change_table :offers, bulk: true do |t|
      t.string :call_to_action_url
      t.string :call_to_action_text
    end
  end

end
