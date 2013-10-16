Timecard::Application.routes.draw do
  resources :members, only: [:destroy]

  resources :work_logs, only: [:edit, :update, :destroy, :stop] do
    patch :stop, on: :member
  end

  resources :issues, only: [:show, :edit, :update, :close, :reopen] do
    patch :close, on: :member
    patch :reopen, on: :member
    resource :work_logs, only: [:start] do
      post :start, on: :member
    end
  end

  resources :projects do
    patch :archive, on: :member
    patch :active, on: :member
    patch :close, on: :member
    resources :issues, only: [:new, :create]
    resources :members, only: [:index, :create]
  end

  delete "users/disconnect/:provider", to: "users#disconnect", as: :disconnect_provider
  devise_for :users, controllers:  { omniauth_callbacks: "users/omniauth_callbacks", registrations: 'users/registrations' }
  root :to => "home#index"
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
end
