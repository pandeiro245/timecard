class Issue < ActiveRecord::Base
  belongs_to :project
  belongs_to :author, class_name: "User", foreign_key: :author_id
  belongs_to :assignee, class_name: "User", foreign_key: :assignee_id
  has_many :work_logs

  validates :subject, presence: true
end
