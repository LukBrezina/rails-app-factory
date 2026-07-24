Rails.application.routes.draw do
  # This box hosts exactly one app (named by APPSMOOTHLY_APP, adopted by App.current),
  # so nothing is scoped by app any more — every page targets that one app.
  root "sessions#index"
  get "start" => "onboarding#show", as: :onboarding
  post "start" => "onboarding#create"
  get "start/link" => "onboarding#link", as: :onboarding_link

  resources :sessions, only: %i[index show create destroy] do
    resources :mails, only: %i[index show] do
      post :forward, on: :member
    end
  end
  resource :production, only: %i[show update] do
    post :deploy
  end
  get "backups" => "backups#show", as: :backups
  patch "backups" => "backups#update"
  post "backups/restore" => "backups#restore", as: :backups_restore
  post "backups/pull/:id" => "backups#pull", as: :backups_pull

  # Caddy on-demand TLS gate: certificates only for p-<port> preview hosts
  # under this box's domain. Rack lambda so it needs no auth/session.
  get "caddy_ask" => ->(env) {
    domain = ENV["APPSMOOTHLY_DOMAIN"]
    asked = Rack::Request.new(env).params["domain"].to_s
    ok = domain && asked.match?(/\Ap-\d+\.#{Regexp.escape(domain)}\z/)
    [ok ? 200 : 404, { "content-type" => "text/plain" }, []]
  }

  get "up" => "rails/health#show", as: :rails_health_check
end
