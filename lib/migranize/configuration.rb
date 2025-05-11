module Migranize
    class Configuration
        attr_accessor :migrations_dir, :models_dir, :ignore_tables, :ignore_namespaces

        def initialize
            @migrations_dir = "db/migrate"
            @models_dir = "app/models"
            @ignore_tables = []
            @ignore_namespaces = []
        end
    end
end