module ApplicationHelper
  def form_errors(errors)
    render partial: 'shared/form_errors', locals: {
      errors: errors
    }
  end
end
