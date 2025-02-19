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
  root "frontend/pages#home"

  #
  # Frontend
  #
  namespace :frontend, path: "/" do
    root "pages#home"

    # redirect old event URLs to new ones
    get "/:id", to: redirect("/termine/%{id}"), constraints: {id: /\d{1,4}.+/}

    resources :courses, only: [:index, :show], path: "kurse"
    resources :events, only: [:index, :show], path: "termine" do
      resources :registrations, only: [:index, :new, :create], path: "anmeldung", module: :events
    end
  end

  #
  # Admin
  #
  namespace :admin do
    root to: redirect("/admin/courses")

    resource :session, only: [:new, :create, :destroy]

    resources :courses, except: [:show] do
      get :preview_reminder_message, path: "preview-reminder-message", on: :member

      resources :events, except: [:show], module: :courses do
        get :duplicate, on: :member
        get :preview_reminder_message, path: "preview-reminder-message", on: :member

        resources :registrations, except: [:show], module: :events do
          get :download_certificate, on: :member, path: "certificate/download"
          patch :send_certificate, on: :member, path: "certificate/send"
          patch :send_reminder_message, on: :member, path: "reminder/send"
          patch :bulk_process, path: "bulk-process", on: :collection
          post :send_message, path: "message/send", on: :collection
        end

        resource :report, except: [:destroy], module: :events

        resource :certification, except: [:destroy], module: :events
      end
    end

    resources :events, only: [:index] do
      get :reports, on: :collection, constraints: {format: :xlsx}
    end

    resources :categories, except: [:show] do
      patch :reorder, on: :member
    end

    resources :target_groups, path: "target-groups", except: [:show] do
      patch :reorder, on: :member
    end

    resources :topics, except: [:show] do
      patch :reorder, on: :member
    end
  end

  # Dev Tools
  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end
end
