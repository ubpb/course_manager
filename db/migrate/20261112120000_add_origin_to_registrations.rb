class AddOriginToRegistrations < ActiveRecord::Migration[8.1]

  # How a registration came about: with the library account, as a guest or
  # entered in the admin. Until now registering took a login, so a missing ILS
  # id meant the admin; with guests that no longer holds.
  def up
    add_column :registrations, :origin, :string
    backfill_origin
  end

  def down
    remove_column :registrations, :origin
  end

  # Until now a login left the ILS id behind, and everything else was entered in
  # the admin. Anonymizing dropped the ILS id, so an anonymized registration
  # without one stays unknown (NULL). The anonymized check mirrors
  # Registration#anonymized?.
  def backfill_origin
    execute <<~SQL.squish
      UPDATE registrations SET origin = 'account'
      WHERE origin IS NULL AND ils_primary_id IS NOT NULL AND ils_primary_id <> ''
    SQL

    execute <<~SQL.squish
      UPDATE registrations SET origin = 'admin'
      WHERE origin IS NULL AND (ils_primary_id IS NULL OR ils_primary_id = '')
        AND first_name <> 'Gelöscht' AND last_name <> 'Gelöscht' AND email <> 'Gelöscht'
    SQL
  end

end
