class RemoveReminderMessageAndEmailFromFromOffers < ActiveRecord::Migration[8.1]
  def up
    # Copy offer.reminder_message down to events whose own reminder_message is blank.
    execute <<~SQL.squish
      UPDATE events
      INNER JOIN offers ON offers.id = events.offer_id
      SET events.reminder_message = offers.reminder_message
      WHERE (events.reminder_message IS NULL OR TRIM(events.reminder_message) = '')
        AND offers.reminder_message IS NOT NULL
        AND TRIM(offers.reminder_message) <> ''
    SQL

    remove_column :offers, :reminder_message
    remove_column :offers, :email_from
  end

  def down
    add_column :offers, :reminder_message, :text
    add_column :offers, :email_from, :string
  end
end
