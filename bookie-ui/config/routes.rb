BookieUi::Application.routes.draw do
  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  root to: 'jobs#index'

  resources :jobs
  resources :systems
  resources :users

  resource :graph, only: [:show]

  resources :web_users
  resources :password_resets

  resource :session
end
