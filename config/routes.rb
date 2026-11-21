Rails.application.routes.draw do
  mount MissionControl::Jobs::Engine, at: "/jobs"

  resource :session, only: %i[ new create destroy ]
  resources :magic_links, only: :show, param: :token do
    resource :consumption, only: :create, controller: "magic_link_consumptions"
  end

  resources :feeds, only: [ :index, :new, :create, :edit, :update, :destroy ] do
    resource :mark_as_read, only: :create, controller: "feed_mark_as_reads"
    resource :fetch, only: :create, controller: "feed_fetches"
    resources :entries, only: [ :index ]
  end

  resources :folders, except: [ :show ]
  resources :users, except: [ :show ]

  resources :feed_imports, only: [ :new, :create ]
  resource :feed_export, only: :show

  resources :entries, only: [ :show ] do
    resource :mark_as_read, only: :create, controller: "entry_mark_as_reads"
    resource :pin, only: %i[ create destroy ], controller: "entry_pins"
    collection do
      get :pinned
    end
  end

  resource :pinned_entry_open, only: :destroy

  get "up" => "rails/health#show", as: :rails_health_check

  root "home#index"
end
