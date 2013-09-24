BookieUi::Application.routes.draw do
  devise_for :web_users, skip: :registrations
  #Disable account deletion on the "edit password" page.
  #See https://github.com/plataformatec/devise/wiki/How-To:-Disable-user-from-destroying-his-account
  #Also disables the "sign up" route
  devise_scope :web_user do
    resource :registration,
      only: [:edit, :update],
      path: 'web_users',
      controller: 'devise/registrations',
      as: :web_user_registration do
        get :cancel
      end
  end
  resources :web_users do
    member do
     patch 'approve'
    end
  end
  

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
