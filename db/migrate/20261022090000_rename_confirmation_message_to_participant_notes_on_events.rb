class RenameConfirmationMessageToParticipantNotesOnEvents < ActiveRecord::Migration[8.1]

  # The text is no longer tied to the confirmation mail: it also goes into the
  # reminder and onto the detail page of a registration. Its meaning stays the
  # same, so the texts are kept.
  def change
    rename_column :events, :confirmation_message, :participant_notes
  end

end
