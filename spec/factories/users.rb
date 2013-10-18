FactoryGirl.define do
  factory :user do
    sequence(:email) {|n| "timecard#{n}@timecard.com" }
    password Devise.friendly_token[0,20]
    password_confirmation { password }
    username "timecard"
  end
end
