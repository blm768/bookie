class AdminMailer < ActionMailer::Base
  default from: "from@example.com"

  def new_web_user_notification(web_user)
    @web_user = web_user
    mail(to: '', subject: 'User waiting for approval')
  end
end

