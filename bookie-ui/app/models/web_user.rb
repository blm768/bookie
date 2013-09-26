class WebUser < ActiveRecord::Base
  attr_accessor :password
  before_save :set_hashed_password

  validates :email, :format => { :with => /@/ }
  validates :email, :uniqueness => { :message => 'is already in use.' }
  validates :password, :confirmation => true

  def set_hashed_password
    return if password.blank?
    self.password_salt = SecureRandom.urlsafe_base64
    self.password_hash = self.hash_password(self.password)
  end

  def hash_password(password)
    Digest::SHA512.hexdigest(password + self.password_salt)
  end
  
  def confirmed?
    self.password_hash != nil
  end
  
  def generate_reset_key
    reset_key = SecureRandom.urlsafe_base64
    #To consider: include salt?
    self.reset_key_hash = Digest::SHA512.hexdigest(reset_key)
    self.reset_sent_at = Time.zone.now
    reset_key
  end

  ##
  #Resets the reset_key_hash and reset_sent_at fields to nil
  #
  #Does not save the record
  def clear_reset_key
    self.reset_key_hash = nil
    self.reset_sent_at = nil
  end

  def correct_reset_key?(reset_key)
    key_hash = Digest::SHA512.hexdigest(reset_key)
    self.reset_key_hash != nil && self.reset_key_hash == key_hash
  end

  def reset_key_expired?
    !reset_sent_at || (Time.zone.now - reset_sent_at) > 1.days
  end

  def self.authenticate(email, password)
    web_user = where(:email => email).first
    if web_user && web_user.password_hash == web_user.hash_password(password)
      web_user
    else
      nil
    end
  end
end


