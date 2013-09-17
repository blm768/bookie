BookieUi::Application.routes.draw do
  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'welcome#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end
  
  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  devise_for :web_users, skip: :registrations
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
