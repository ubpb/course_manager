class CreateOffers < ActiveRecord::Migration[8.1]

  # Schema-lokale Leichtgewicht-Modelle, damit die Migration nicht von den
  # App-Modellen (Course/Consulting/Offer) abhängt.
  class Course < ActiveRecord::Base; end
  class Consulting < ActiveRecord::Base; end

  class Offer < ActiveRecord::Base
    self.inheritance_column = nil # `type` als normales Attribut, kein STI
  end

  def up
    create_table :offers do |t|
      t.string :type, null: false, index: true
      t.bigint :old_id, index: true
      t.string :title, null: false
      t.boolean :published, null: false, default: false, index: true
      t.text :description
      t.text :learning_targets
      t.text :reminder_message
      t.string :email_from
      t.string :contact_name
      t.string :contact_email
      t.string :contact_phone
      t.timestamps
    end

    create_join_table :offers, :topics, column_options: {null: false, foreign_key: true}
    create_join_table :offers, :target_groups, column_options: {null: false, foreign_key: true}

    add_reference :events, :offer, foreign_key: true, null: true

    course_map = {}     # course.id     => offer.id
    consulting_map = {} # consulting.id => offer.id

    #
    # Courses -> offers
    #
    Course.find_each do |course|
      offer = Offer.create!(
        type: "course",
        old_id: course.id,
        title: course.title,
        published: course.published,
        description: course.description,
        learning_targets: course.learning_targets,
        reminder_message: course.reminder_message,
        email_from: course.email_from,
        created_at: course.created_at,
        updated_at: course.updated_at
      )
      course_map[course.id] = offer.id
    end

    copy_join_table("courses_topics", "course_id", "topic_id", "offers_topics", "topic_id", course_map)
    copy_join_table("courses_target_groups", "course_id", "target_group_id", "offers_target_groups", "target_group_id", course_map)

    #
    # Consultings -> offers
    #
    Consulting.find_each do |consulting|
      offer = Offer.create!(
        type: "consulting",
        old_id: consulting.id,
        title: consulting.title,
        published: consulting.published,
        description: consulting.description,
        contact_name: consulting.contact_name,
        contact_email: consulting.contact_email,
        contact_phone: consulting.contact_phone,
        created_at: consulting.created_at,
        updated_at: consulting.updated_at
      )
      consulting_map[consulting.id] = offer.id
    end

    copy_join_table("consultings_topics", "consulting_id", "topic_id", "offers_topics", "topic_id", consulting_map)
    copy_join_table("consultings_target_groups", "consulting_id", "target_group_id", "offers_target_groups", "target_group_id", consulting_map)

    #
    # Events auf den jeweiligen Course-Offer umhängen
    #
    select_all("SELECT id, course_id FROM events").each do |row|
      offer_id = course_map[row["course_id"]]
      execute("UPDATE events SET offer_id = #{offer_id} WHERE id = #{row["id"]}") if offer_id
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Die Migration kann nicht zurückgesetzt werden, da die ursprünglichen Course- und Consulting-Daten nicht wiederhergestellt werden können."
  end

  private

  # Überträgt eine HABTM-Join-Tabelle in die offers-Pendant-Tabelle, wobei die
  # Quell-IDs über `id_map` (alte ID => offer.id) auf die neuen Offer-IDs gemappt werden.
  def copy_join_table(source_table, source_fk, assoc_fk, target_table, target_assoc_fk, id_map)
    select_all("SELECT #{source_fk}, #{assoc_fk} FROM #{source_table}").each do |row|
      offer_id = id_map[row[source_fk]]
      next unless offer_id

      execute(
        "INSERT INTO #{target_table} (offer_id, #{target_assoc_fk}) " \
        "VALUES (#{offer_id}, #{row[assoc_fk]})"
      )
    end
  end

end
