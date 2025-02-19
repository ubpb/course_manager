class Report < ApplicationRecord

  # Relations
  belongs_to :event

  # Validations
  validates :duration, presence: true, numericality: {greater_than_or_equal_to: 0}
  validates :number_of_participants, presence: true, numericality: {only_integer: true, greater_than_or_equal_to: 0}
  validates :lecturer, presence: true
  validates :lecturer_md, numericality: {only_integer: true, greater_than_or_equal_to: 0}
  validates :lecturer_gd, numericality: {only_integer: true, greater_than_or_equal_to: 0}
  validates :lecturer_hd, numericality: {only_integer: true, greater_than_or_equal_to: 0}

  # Flags
  flag :presence_types,      [:presence,
                              :online]
  flag :organization_types,  [:library,
                              :integrated,
                              :independent,
                              :consultation,
                              :media,
                              :webinar,
                              :elearning,
                              :blended]
  flag :forms,               [:presentation,
                              :workshop]
  flag :levels,              [:beginner,
                              :advanced]
  flag :categories,          [:interdisciplinary,
                              :english_studies,
                              :german_studies,
                              :romance_studies,
                              :history,
                              :art_history,
                              :musicology,
                              :philosophy,
                              :theology,
                              :nutritional_science,
                              :computer_science,
                              :engineering,
                              :chemistry,
                              :geography,
                              :physics,
                              :natural_science,
                              :media_studies,
                              :pedagogy,
                              :sociology,
                              :psychology,
                              :economics,
                              :sports,
                              :other]
  flag :audiences,           [:bachelor_students,
                              :master_students,
                              :tutors,
                              :phd_students,
                              :scientists,
                              :university_others,
                              :pupils,
                              :trainees,
                              :teachers,
                              :seniors,
                              :foreign_students,
                              :others]
  flag :focus,               [:information_competence,
                              :library_usage,
                              :search_methods,
                              :catalogs,
                              :internet_research,
                              :information_management,
                              :legal_issues,
                              :electronic_publishing,
                              :interlending,
                              :scientific_work,
                              :special_collections,
                              :others]

end
