Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      # Auth (unauthenticated)
      namespace :auth do
        post "signup", to: "registrations#create"
        post "login",  to: "sessions#create"
        delete "logout", to: "sessions#destroy"
      end

      # Authenticated profile
      get "me", to: "me#show"

      # Organizer-managed sweepstakes (auth required)
      resources :sweepstakes, only: %i[index create show update destroy] do
        member do
          post :lock
          post :draw
          post :reset_draw
        end
        resources :entries, only: %i[index create] do
          collection { post :bulk }
        end
        resources :participants, only: %i[index]
      end
      resources :entries, only: %i[update destroy]
      resources :participants, only: %i[destroy]

      # Public, read-only competition templates (for the create form)
      resources :templates, only: %i[index show], param: :slug

      # Platform-admin template management
      namespace :admin do
        resources :templates, only: %i[index show create update destroy], param: :slug
      end

      # Public share page + participant registration (no auth; gated by share_token)
      scope "s/:share_token", controller: "public/shares" do
        get   "/",            action: :show
        post  "register",     action: :register
        get   "me",           action: :me
        get   "results",      action: :results
        get   "verification", action: :verification
      end
    end
  end
end
