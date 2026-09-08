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

  # User account
  namespace :account do
    root "registrations#index"
    resources :registrations, only: [:destroy], path: "anmeldungen" do
      get :certificate, on: :member, path: "teilnahmebescheinigung"
    end
  end

  # Defines the root path route ("/")
  root "frontend/pages#home"

  #
  # Frontend
  #
  namespace :frontend, path: "/" do
    root "pages#home"
    get  "kontakt", to: "pages#contact", as: :contact

    # XML sitemap for search engines (referenced from public/robots.txt)
    get "sitemap.xml", to: "sitemaps#show", as: :sitemap, defaults: {format: "xml"}

    # Offers
    scope "angebote" do
      # Redirects for legacy/filter URLs. Must be defined before the resources :offers route,
      # as "kurse" etc. will wrongfully match the :id parameter of the show route.
      get "/kurse(/:id)", to: "offers#redirect_courses", as: :redirect_courses
      get "/beratungen(/:id)", to: "offers#redirect_consultings", as: :redirect_consultings
      get "/termine(/:id)", to: "offers#redirect_events", as: :redirect_events

      # Offers
      resources :offers, only: [:index, :show], path: "/"

      # Event registrations
      resources :events, only: [], path: "termine" do
        resources :registrations, only: [:index, :new, :create], path: "anmeldung", module: :events
      end
    end

    resources :cert_checks, path: "validate", only: [:index, :new, :create, :show]
  end

  #
  # Admin
  #
  namespace :admin do
    root to: redirect("/admin/events")

    resource :session, only: [:new, :create, :destroy]

    resources :offers, except: [:show] do
      patch :bulk_process, path: "bulk-process", on: :collection

      resources :events, except: [:show], module: :offers do
        get :duplicate, on: :member
        get :preview_confirmation_message, path: "preview-confirmation-message", on: :member
        patch :bulk_process, path: "bulk-process", on: :collection
        patch :bulk_move, path: "bulk-move", on: :collection

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
      patch :bulk_process, path: "bulk-process", on: :collection
      patch :bulk_move, path: "bulk-move", on: :collection
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
