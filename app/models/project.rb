class Project < ActiveRecord::Base
  STATUS_ACTIVE   = 1
  STATUS_CLOSED   = 5
  STATUS_ARCHIVED = 9

  scope :active, -> { where(status: STATUS_ACTIVE) }
  scope :public, -> { where(is_public: true) }

  has_many :members, dependent: :destroy

  validates :name, presence: true
end
