# Admin / review UI. Drawn only for the web role, so none of this exists on public.
get "admin/up" => "rails/health#show", as: :admin_health_check

namespace :admin do
  root "dashboard#show"
  resource :interview, only: :show do
    post :answer
    post :finish
  end
end

resource :session, only: %i[new create destroy]

# First-run setup: Create Admin -> Enter Site URL (Technical Architecture §48).
# Reachable only until one user and one site exist; 404 afterwards.
scope :setup, controller: :setup, as: :setup do
  get  "/",    action: :new
  post "/",    action: :create
  get  "site", action: :site
  post "site", action: :create_site
end
