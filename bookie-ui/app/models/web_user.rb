class WebUser < ActiveRecord::Base
  validates :email, :presence => true, :format => { :with => /@/ }
  #TODO: make case-insensitive?
  #TODO: internationalize?
  validates :email, :uniqueness => { :message => 'is already in use.' }
  #validates :password, :confirmation => true
  
  #TODO: validation on reset_key_hash?
  

  def confirmed?
    self.password_hash != nil
  end
  
  def generate_reset_key
    reset_key = SecureRandom.urlsafe_base64
    #TODO: include salt?
    #Generate a reset key hash.
    self.reset_key_hash = Digest::SHA512.hexdigest(reset_key)
    self.reset_sent_at = Time.zone.now
    reset_key
  end

  def clear_reset_key
    self.reset_key_hash = nil
    self.reset_sent_at = nil
  end

  def correct_reset_key?(reset_key)
    key_hash = Digest::SHA512.hexdigest(reset_key)
    self.reset_key_hash != nil && self.reset_key_hash == key_hash
  end

  #TODO: handle reset key expiration.

end

