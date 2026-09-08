Rails.application.routes.draw do
  # Health check for PaaS load balancers, served by every HTTP role.
  get "up" => "rails/health#show", as: :rails_health_check

  # Generated pages. Served by both the web and public roles.
  draw(:public)

  # Admin / review UI. Only mounted on the web role (Technical Architecture §46).
  draw(:admin) if AppRole.web?
end
