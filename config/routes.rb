Rails.application.routes.draw do
  mount MissionControl::Jobs::Engine, at: "/jobs"

  resource :session
  resource :password, only: [ :edit, :update ]

  resources :feeds, only: [ :index, :new, :create, :edit, :update, :destroy ] do
    resource :mark_as_read, only: :create, controller: "feed_mark_as_reads"
    resource :fetch, only: :create, controller: "feed_fetches"
    resources :entries, only: [ :index ]
  end

  resources :folders, except: [ :show ]

  resources :feed_imports, only: [ :new, :create ]
  resource :feed_export, only: :show

  resources :entries, only: [ :show ] do
    resource :mark_as_read, only: :create, controller: "entry_mark_as_reads"
    resource :pin, only: :create, controller: "entry_pins"
    collection do
      get :pinned
    end
  end

  resource :pinned_entry_open, only: [ :create, :destroy ]

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
