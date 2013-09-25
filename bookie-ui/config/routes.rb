BookieUi::Application.routes.draw do
  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".
 
  #root :to => redirect('/web_users/sign_in')
  root :to => 'jobs#index'

  resources :jobs
  resources :systems
  resources :users

  resources :graphs
end
