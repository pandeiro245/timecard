class Project < ActiveRecord::Base
  STATUS_ACTIVE   = 1
  STATUS_CLOSED   = 5
  STATUS_ARCHIVED = 9

  scope :active, -> { where(status: STATUS_ACTIVE) }
  scope :archive, -> { where(status: STATUS_ARCHIVED) }
  scope :public, -> { where(is_public: true) }

  has_many :members, dependent: :destroy
  has_many :issues, dependent: :destroy

  validates :name, presence: true

  def admin?(user)
    member?(user) ? members.find_by("user_id = ?", user.id).is_admin : false
  end

  def member?(user)
    members.exists?(["user_id = ?", user.id])
  end
end
