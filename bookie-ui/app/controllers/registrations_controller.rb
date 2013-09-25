class RegistrationsController < Devise::RegistrationsController
  before_controller :authenticate_web_user!
end
