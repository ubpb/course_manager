class DropCoursesAndConsultings < ActiveRecord::Migration[8.1]

  def up
    # events.offer_id is backfilled; drop the legacy course_id and require offer_id.
    remove_reference :events, :course, foreign_key: true
    change_column_null :events, :offer_id, false

    # Drop legacy HABTM join tables, then the base tables.
    drop_table :courses_topics
    drop_table :courses_target_groups
    drop_table :consultings_topics
    drop_table :consultings_target_groups
    drop_table :courses
    drop_table :consultings
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
      "Die ursprünglichen Course- und Consulting-Tabellen können nicht wiederhergestellt werden."
  end

end
