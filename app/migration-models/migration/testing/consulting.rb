class Migration::Testing::Consulting < Migration::Testing::ApplicationRecord

  self.table_name = "consultings"

  has_and_belongs_to_many :topics, class_name: "Migration::Testing::Topic"
  has_and_belongs_to_many :target_groups, class_name: "Migration::Testing::TargetGroup"

end
