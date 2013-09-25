#See https://github.com/plataformatec/devise/wiki/How To: Email-only sign-up
class ConfirmationsController < Devise::ConfirmationsController
  def show
    if params[:confirmation_token].present?
      confirmation_token = Devise.token_generator.digest(resource_class, :confirmation_token, params[:confirmation_token])
      self.resource = resource_class.find_by(:confirmation_token => confirmation_token)
    end
    raise resource_class.all.inspect if resource.nil?
    super if resource.nil? or resource.confirmed?
  end

  def confirm
    if params[resource_name][:confirmation_token].present?
      self.resource = resource_class.find_by(:confirmation_token => params[resource_name][:confirmation_token])
    end

    update_params = ActionController::Parameters.new(params[resource_name].except(:confirmation_token))
    if resource.update_attributes(update_params.permit(:password, :password_confirmation)) && resource.password_match?
      self.resource = resource_class.confirm_by_token(params[resource_name][:confirmation_token])
      if resource.errors.empty?
        render :action => 'show'
      else
        set_flash_message :notice, :confirmed
        sign_in_and_redirect(resource_name, resource)
      end
    else
      render :action => 'show'
    end
  end
end
