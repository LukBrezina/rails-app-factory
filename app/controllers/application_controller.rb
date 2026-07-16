class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # The terminal grants a real shell, so auth fails closed: serve only with a
  # password, or an explicit RAF_TRUST_NETWORK=1 opt-out (the tailscale-only
  # deploy, where the network is the boundary — see setup.sh). Never silently open.
  if ENV["RAILS_APP_FACTORY_PASSWORD"].present?
    http_basic_authenticate_with name: ENV.fetch("RAILS_APP_FACTORY_USER", "admin"),
                                 password: ENV["RAILS_APP_FACTORY_PASSWORD"]
  elsif ENV["RAF_TRUST_NETWORK"].blank?
    before_action do
      render plain: "Refusing to start unauthenticated. Set RAILS_APP_FACTORY_PASSWORD to require a " \
                    "login, or RAF_TRUST_NETWORK=1 if this is only reachable over a private network " \
                    "(e.g. tailscale).", status: :service_unavailable
    end
  end

  helper_method :preview_host

  private

  def preview_host = Factory.preview_host || request.host
end
