class RenameReminderMessageToConfirmationMessageOnEvents < ActiveRecord::Migration[8.1]

  # The field changes its meaning: it used to hold the whole reminder mail body,
  # it now holds an optional block appended to the (static) registration
  # confirmation. The old texts are worded as reminders, so they are dropped.
  def up
    rename_column :events, :reminder_message, :confirmation_message
    execute "UPDATE events SET confirmation_message = NULL"
  end

  def down
    rename_column :events, :confirmation_message, :reminder_message
  end

end
