class WebUserMailer < ActionMailer::Base
  default from: "from@example.com"

  def confirmation(web_user, confirmation_key)
    @web_user = web_user
    @confirmation_key = web_user.generate_reset_key
    @url = show_password_reset_path(:email => web_user.email, :key => confirmation_key)
    mail(:to => web_user.email, :subject => 'Account confirmation')
  end
end
