BookieUi::Application.routes.draw do
  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".
 
  devise_for :web_users, :skip => :registrations, :controllers => {
    :confirmations => 'confirmations',
    :registrations => 'registrations'
  }

  #Disable account deletion on the "edit password" page.
  #See https://github.com/plataformatec/devise/wiki/How-To:-Disable-user-from-destroying-his-account
  devise_scope :web_user do
    resource :registration,
      only: [:new, :create, :edit, :update],
      path: 'web_users',
      path_names: { new: 'sign_up' },
      controller: 'devise/registrations',
      as: :web_user_registration do
        get :cancel
      end
    put '/web_users/confirmation' => 'confirmations#confirm'
  end
  resources :web_users

  # See https://github.com/plataformatec/devise/wiki/How-To:-Require-authentication-for-all-pages
  authenticated :web_user do
    root :to => 'jobs#index', :as => :authenticated_root
  end
  root :to => redirect('/web_users/sign_in')

  resources :jobs
  resources :systems
  resources :users

  resources :graphs
end
