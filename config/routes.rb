Rails.application.routes.draw do
  get "checkout" => "checkout_sessions#new", as: :new_checkout
  post "checkout" => "checkout_sessions#create"
  get "checkout_sessions/:id" => "checkout_sessions#show", as: :checkout_session
  post "stripe/webhook" => "stripe_webhooks#receive"
  get "checkout/success" => "checkout_sessions#success", as: :checkout_success
  get "checkout/cancel" => "checkout_sessions#cancel", as: :checkout_cancel

  resource :cart, only: [ :show ]
  resources :cart_items, only: [ :create, :destroy ]

  resources :certificates
  get "certificates/:id/preview" => "certificates#preview", as: :preview_certificate

  get "documents/index" => "documents#index"
  get "/up" => "health#up"
  get "/favicon.ico" => redirect("/favicon.svg")

  # Rails built-in authentication
  resource :session
  get "sign-up" => "sessions#new_signup", as: :new_signup
  get "session/authenticate/*token" => "sessions#authenticate", as: :authenticate_session
  resources :passwords, param: :token

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "landing#index"
end
