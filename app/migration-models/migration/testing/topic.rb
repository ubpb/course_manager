class Migration::Testing::Topic < Migration::Testing::ApplicationRecord

  self.table_name = "topics"

  has_and_belongs_to_many :consultings, class_name: "Migration::Testing::Consulting"

end
