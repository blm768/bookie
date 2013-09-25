class WebUserMailer < ActionMailer::Base
  default from: "from@example.com"

  def confirmation(web_user, confirmation_key)
    @web_user = web_user
    @confirmation_key = confirmation_key
    @url = password_resets_edit_url(:email => web_user.email, :key => confirmation_key)
    mail(:to => web_user.email, :subject => 'Account confirmation')
  end
end
