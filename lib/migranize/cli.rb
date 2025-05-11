require "thor"

module Migranize
    class CLI < Thor
        desc "init", "Initialize Migranize in your project"
        def init
            create_file("config/migranize.rb", config_template)

            say "Migranize initialized successfully!", :green
            say "\nUsage:", :green
            say "  To create migrations based on your model changes:", :green
            say "    migranize make_migrations", :green
            say "  To run migrations, use Rails:", :green
            say "    rails db:migrate", :green
        end

        desc "make_migrations", "Generate migrations for model changes"
        def make_migrations
            require File.expand_path('config/migranize')

            load_environment
              
            if defined?(ActiveRecord::Base) && !ActiveRecord::Base.respond_to?(:field)
                 ActiveRecord::Base.include(Migranize::FieldDefinition)
            end
              
            ensure_application_record if defined?(ActiveRecord::Base)
            
            if defined?(ActiveRecord::Base) && !ActiveRecord::Base.connected?
                # say "Connecting to database...", :blue
                begin
                  if ActiveRecord::Base.respond_to?(:connection_pool) && ActiveRecord::Base.connection_pool.respond_to?(:connection)
                    ActiveRecord::Base.connection_pool.connection
                  else
                    ActiveRecord::Base.establish_connection
                  end
                  # say "Connected to database.", :green
                rescue => e
                  say "Failed to connect to database: #{e.message}", :red
                  say "Will proceed without database connection. This may affect migration generation.", :yellow
                end
            end
            
            if Migration::Generator.generate_for_all_models
              say "Migrations generated successfully!", :green
            else
              say "No model changes detected.", :yellow
            end
        end

        private

        def ensure_application_record
            return if defined?(ApplicationRecord)
            
            Object.const_set(:ApplicationRecord, Class.new(ActiveRecord::Base) {
              self.abstract_class = true
            })
            
            ApplicationRecord.include(Migranize::FieldDefinition)
          end

        def create_file(path, content)
            full_path = File.join(Dir.pwd, path)

            FileUtils.mkdir_p(File.dirname(full_path))

            if File.exist?(full_path)
                if yes?("File #{path} already exists. Overwrite? (y/n)")
                    File.write(full_path, content)
                    say "Overwrote file: #{path}", :green
                end
            else
                File.write(full_path, content)
                say "Created file: #{path}", :green
            end
        end

        def load_environment
            env_file = File.join(Dir.pwd, "config", "environment.rb")

            unless File.exist?(env_file)
                say "Environment file not found.", :red
                exit 1
            end

            require env_file
        end

        def config_template
            <<~RUBY
             # Migranize Configuration
             
             Migranize.configure do |config|
                config.ignore_namespaces = []
                config.ignore_tables = []
                config.migrations_dir = "db/migrate"
                config.models_dir = "app/models"
             end
            RUBY
        end
    end
end