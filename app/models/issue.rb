class Issue < ActiveRecord::Base
  belongs_to :project
  belongs_to :author, class_name: "User", foreign_key: :author_id

  validates :subject, presence: true
end
