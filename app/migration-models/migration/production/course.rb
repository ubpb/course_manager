class Migration::Production::Course < Migration::Production::ApplicationRecord
  self.table_name = "training_courses"

  # Flags
  flag :statistics_presence_types,      [ :presence,
                                          :online ]
  flag :statistics_organization_types,  [ :library,
                                          :integrated,
                                          :independent,
                                          :consultation,
                                          :media,
                                          :webinar,
                                          :elearning,
                                          :blended ]
  flag :statistics_forms,               [ :presentation,
                                          :workshop ]
  flag :statistics_levels,              [ :beginner,
                                          :advanced ]
  flag :statistics_categories,          [ :interdisciplinary,
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
                                          :other ]
  flag :statistics_audiences,           [ :bachelor_students,
                                          :master_students,
                                          :tutors,
                                          :phd_students,
                                          :scientists,
                                          :university_others,
                                          :pupils,
                                          :trainees,
                                          :teachers,
                                          :seniors,
                                          :forign_students,
                                          :others ]
  flag :statistics_focus,               [ :information_competence,
                                          :library_usage,
                                          :search_methods,
                                          :catalogs,
                                          :internet_research,
                                          :information_managment,
                                          :legal_issues,
                                          :electronic_publishing,
                                          :interlending,
                                          :scientific_work,
                                          :special_collections,
                                          :others ]

end
