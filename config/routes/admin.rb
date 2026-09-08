# Admin / review UI routes land here (issue #2 onwards).
# Until then, an admin-scoped health check proves the role split works.
get "admin/up" => "rails/health#show", as: :admin_health_check
