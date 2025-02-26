Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Authentication
  get  "/login",  to: "sessions#new", as: :new_session
  post "/login",  to: "sessions#create", as: :session
  get  "/logout", to: "sessions#destroy", as: :logout

  # Locale switching
  get "/locale/:locale", to: "locales#switch", as: :locale

  # Defines the root path route ("/")
  root "pages#home"

  #
  # Admin
  #
  namespace :admin do
    root to: redirect("/admin/courses")

    resource :session, only: [:new, :create, :destroy]

    resources :courses, except: [:show] do
      resources :events, except: [:show], module: :courses do
        get :duplicate, on: :member
        resources :registrations, except: [:show], module: :events
        resource :report, except: [:destroy], module: :events
      end
    end

    resources :events, only: [:index]
  end

  # Dev Tools
  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end
end
