# Parse and validate the product-fixed archetype master at boot, so a broken
# YAML fails the deployment instead of the first request that needs it.
Rails.application.config.after_initialize do
  ArchetypeDefinition.all
end
