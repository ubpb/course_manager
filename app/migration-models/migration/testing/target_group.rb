class Migration::Testing::TargetGroup < Migration::Testing::ApplicationRecord

  self.table_name = "target_groups"

  has_and_belongs_to_many :consultings, class_name: "Migration::Testing::Consulting"

end
