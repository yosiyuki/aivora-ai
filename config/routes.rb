Rails.application.routes.draw do
  # Health check for PaaS load balancers, served by every HTTP role.
  get "up" => "rails/health#show", as: :rails_health_check

  # Admin / review UI. Only mounted on the web role (Technical Architecture §46).
  # Drawn before the public routes because those end in a catch-all that would
  # otherwise swallow every admin path.
  draw(:admin) if AppRole.web?

  # Generated pages. Served by both the web and public roles.
  draw(:public)
end
