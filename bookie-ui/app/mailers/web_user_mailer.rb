class WebUserMailer < ActionMailer::Base
  default from: "from@example.com"

  def confirmation(web_user, confirmation_key)
    @web_user = web_user
    @confirmation_key = confirmation_key
    @url = edit_password_reset_url(web_user.id, :key => confirmation_key)
    mail(:to => web_user.email, :subject => 'Account confirmation')
  end

  def reset_password(web_user, reset_key)
    @web_user = web_user
    @confirmation_key = reset_key
    @url = edit_password_reset_url(web_user.id, :key => reset_key)
    mail(:to => web_user.email, :subject => 'Reset password')
  end
end
