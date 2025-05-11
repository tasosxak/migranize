# Migranize Configuration

Migranize.configure do |config|
   config.ignore_namespaces = ["ActiveStorage", "ActionText"]
   config.migrations_dir = "db/migrate"
   config.models_dir = "app/models"
end
