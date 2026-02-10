Rails.application.routes.draw do
  resource :session

  resources :feeds, only: [ :index ] do
    collection do
      get :import
      post :import, action: :create_import
    end
    member do
      post :mark_all_as_read
    end
    resources :entries, only: [ :index ]
  end

  resources :entries, only: [ :show ] do
    collection do
      get :pinned
    end
    member do
      patch :mark_as_read
      patch :toggle_pin
    end
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "home#index"
end
