Rails.application.routes.draw do

  resources :administrators

  get 'admin/index'
  get 'admin' => 'admin#index'
  get 'admin/log'
  get 'admin/logout'
  get 'admin/status'
  get 'admin/lists'
  get 'admin/download_cron'
  get 'admin/conversions'
  get 'admin/reject'

  post 'conversions/validate'

  resources :listservlists
  resources :conversions

  get 'oauth/callback'
  get 'oauth2callback' => 'oauth#callback'

  get 'gengroups' => 'listservlists#gengroups'
  get 'home/index'

  get 'discontinue/:id' => 'listservlists#discontinue_ask'
  get 'discontinue_confirm/:id' => 'listservlists#discontinue'

  root 'home#index'


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
