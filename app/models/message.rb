class Message

  include ActiveModel::API
  include ActiveModel::Attributes

  attribute :subject, :string
  attribute :body, :string

  validates :subject, presence: true
  validates :body, presence: true

end
