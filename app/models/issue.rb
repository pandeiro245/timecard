class Issue < ActiveRecord::Base
  belongs_to :project
  belongs_to :author, class_name: "User", foreign_key: :author_id
  has_many :work_logs

  validates :subject, presence: true
end
