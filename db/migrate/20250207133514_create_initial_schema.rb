class CreateInitialSchema < ActiveRecord::Migration[8.0]

  def change
    #
    # Courses
    #
    create_table :courses do |t|
      t.string :title, null: false
      t.boolean :published, null: false, default: false, index: true
      t.text :description
      t.text :learning_targets
      t.text :reminder_message
      t.string :email_from
      t.timestamps
    end

    #
    # Events
    #
    create_table :events do |t|
      t.references :course, null: false, foreign_key: true
      t.integer :registrations_count, default: 0, null: false
      t.datetime :date_and_time, null: false
      t.integer :duration
      t.string :location
      t.text :reminder_message
      t.string :email_from
      t.boolean :online, null: false, default: false
      t.boolean :published, null: false, default: false, index: true
      t.boolean :registration_required, default: false, null: false
      t.integer :max_no_of_participants, default: 0, null: false
      t.timestamps
    end

    #
    # Registrations
    #
    create_table :registrations do |t|
      t.references :event, null: false, foreign_key: true
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email, null: false
      t.string :field_of_interest
      t.text :user_notes
      t.text :internal_notes
      t.boolean :gdrp_consent, null: false, default: false
      t.timestamp :reminder_message_sent_at
      t.timestamp :certificate_sent_at
      t.timestamps
    end

    #
    # Reports
    #
    create_table :reports do |t|
      t.references :event, null: false, foreign_key: true, index: {unique: true}
      t.integer :duration, default: 0
      t.integer :number_of_participants, default: 0
      t.string :lecturer
      t.integer :lecturer_md, default: 0
      t.integer :lecturer_gd, default: 0
      t.integer :lecturer_hd, default: 0
      t.integer :presence_types, default: 0
      t.integer :organization_types, default: 0
      t.integer :forms, default: 0
      t.integer :levels, default: 0
      t.integer :categories, default: 0
      t.integer :audiences, default: 0
      t.integer :focus, default: 0
      t.timestamps
    end

    #
    # Certifications
    #
    create_table :certifications do |t|
      t.references :event, null: false, foreign_key: true, index: {unique: true}
      t.text :learning_results
      t.string :signature
      t.timestamps
    end

    #
    # Certificates
    #
    create_table :certificates do |t|
      t.references :registration, null: true, foreign_key: true
      t.string :digest, null: false
      t.string :initials, null: false
      t.timestamps
    end

    #
    # Course categories
    #
    create_table :categories do |t|
      t.string :title, null: false, index: {unique: true}
      t.string :color_code, null: false
      t.timestamps
    end

    add_reference :courses, :category, null: true, foreign_key: true

    #
    # Course topics
    #
    create_table :topics do |t|
      t.string :title, null: false, index: {unique: true}
      t.integer :position, index: true
      t.timestamps
    end

    create_join_table :courses, :topics, column_options: {null: false, foreign_key: true}

    #
    # Target groups
    #
    create_table :target_groups do |t|
      t.string :title, null: false, index: {unique: true}
      t.integer :position, index: true
      t.timestamps
    end

    create_join_table :courses, :target_groups, column_options: {null: false, foreign_key: true}
  end

end
