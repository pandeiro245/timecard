class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable,
         :omniauthable, omniauth_providers: [:github]

  has_many :authentications, dependent: :destroy
  has_many :members, dependent: :destroy
  has_many :work_logs

  def apply_omniauth_with_github(omniauth)
    self.email = omniauth.info.email if self.email.blank?
    self.password = Devise.friendly_token[0,20] if self.encrypted_password.blank?
    authentications.build(
      provider: omniauth.provider,
      uid: omniauth.uid,
      username: omniauth.info.nickname,
      oauth_token: omniauth.credentials.token
    )
  end

  def github_username
    github.username
  end

  def github
    authentications.where(provider: "github").first
  end

  def connected?(provider)
    authentications.where(provider: provider).exists?
  end
end
