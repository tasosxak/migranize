require 'colorize'

module Migranize
    class SchemaComparator
        class << self
            # Compares a model's defined fields (`migranize_fields`) with the actual columns in the corresponding database table.
            #
            # It identifies:
            # - Fields that need to be added (`:add_fields`)
            # - Fields that are no longer defined in the model and should be removed from the DB (`:remove_fields`)
            # - Fields that exist in both but differ in type (`:change_fields`)
            #
            # @param model_class [Class] The ActiveRecord-like model class with `migranize_fields` defined
            # @return [Hash] A hash with keys:
            #   - :add_fields [Array<Field>] fields present in model but not in DB
            #   - :remove_fields [Array<Field>] fields present in DB but not in model
            #   - :change_fields [Array<Field>] fields with type mismatch
            #
            # Example return:
            #   {
            #     add_fields: [Field(name: :title, type: :string)],
            #     remove_fields: [Field(name: :old_column, type: :string)],
            #     change_fields: [Field(name: :age, type: :integer)]
            #   }
            def compare_model_with_db(model_class)
                return {} unless model_class.respond_to?(:migranize_fields)

                model_fields = model_class.migranize_fields
                table_name = model_class.table_name
                
                changes = {
                  add_fields: [],
                  remove_fields: [],
                  change_fields: []
                }
                
                unless table_exists?(table_name)
                  model_fields.each do |name, field|
                    changes[:add_fields] << field
                  end
                  return changes
                end
                
                db_columns = get_table_columns(table_name)
                Migranize.logger.debug "table name: #{table_name}\n"
                Migranize.logger.debug "column names: #{db_columns.map(&:name).join(", ")}"

                model_fields.each do |name, field|
                  column_name = name.to_s
                  
                  if !column_exists?(table_name, column_name)
                    changes[:add_fields] << field
                  elsif !compatible_type?(table_name, column_name, field.type)
                    changes[:change_fields] << field
                  end
                end
                
                db_columns.each do |column|
                  next if ["id", "created_at", "updated_at"].include?(column.name)
                  
                  if !model_fields.key?(column.name.to_sym)
                    changes[:remove_fields] << Field.new(
                      column.name, 
                      rails_type_to_model_type(column.type),
                      {}
                    )
                  end
                end

                changes
            end

            # Compares all ActiveRecord models that include `migranize_fields` against their corresponding
            # database tables, collecting differences in structure (fields to add, change, or remove).
            #
            # This method skips models or tables based on the configuration (`ignore_namespaces`, `ignore_tables`).
            # Logs actions and prints changes for each model with discrepancies.
            #
            # @return [Hash{Class => Hash}] A hash mapping each model class to its respective changes:
            #   - :add_fields [Array<Field>]
            #   - :remove_fields [Array<Field>]
            #   - :change_fields [Array<Field>]
            #
            # Example return:
            #   {
            #     User => {
            #       add_fields: [...],
            #       remove_fields: [...],
            #       change_fields: [...]
            #     },
            #     Post => {
            #       ...
            #     }
            #   }
            def compare_all_models
                check_for_unaplied_migrations!
                
                changes_by_model = {}

                ignore_namespaces = Migranize.configuration.ignore_namespaces
                all_models = find_all_ar_models_with_migranize

                all_models.each do |model_class|
                    if ignore_namespaces.any? { |ns| model_class.to_s.start_with?(ns) }
                      Migranize.logger.warn "Skipping model #{model_class.to_s} (ignored namespace)"
                      next
                    end
                
                    if Migranize.configuration.ignore_tables.include?(model_class.table_name)
                       Migranize.logger.warn "Skipping model #{model_class.to_s} (ignored table: #{model_class.table_name})"
                      next
                    end
                
                    next unless model_has_migranize_fields?(model_class)

                    changes = compare_model_with_db(model_class)

                    if changes[:add_fields].any? || changes[:remove_fields].any? || changes[:change_fields].any?
                      puts "#{model_class.to_s}".bold
                      puts "\sAdd fields: #{changes[:add_fields].map(&:name).join(', ').bold}".green if changes[:add_fields].any?
                      puts "\sChange fields: #{changes[:change_fields].map(&:name).join(', ').bold}".yellow if changes[:change_fields].any?
                      puts "\sRemove fields: #{changes[:remove_fields].map(&:name).join(', ').bold}".red if changes[:remove_fields].any?
                      changes_by_model[model_class] = changes
                    end
                end

                Migranize.logger.info "Found changes for #{changes_by_model.keys.count} models."
                changes_by_model
            end

            private

            def check_for_unaplied_migrations!
              un_migrations = unapplied_migrations

              if un_migrations.any?
                puts "There are unapplied migrations!".bold.red
                un_migrations.each do |f|
                  puts f.to_s.red
                end

                exit(1)
              end
            end

            def unapplied_migrations
              migration_files = Dir.glob(File.join(Migranize.configuration.migrations_dir, "*.rb")).sort
              applied_migrations = ActiveRecord::Base.connection.execute("SELECT version FROM schema_migrations").map { |row| row["version"] }

              migration_files.filter do |file|
                version = File.basename(file).split("_").first
                !applied_migrations.include?(version)
              end
            end

            def model_has_migranize_fields?(model_class)
                model_class.respond_to?(:migranize_fields) && 
                !model_class.migranize_fields.empty?
            end

            def find_all_ar_models_with_migranize
                if defined?(Rails) && Rails.application
                  Rails.application.eager_load! if Rails.env.development?
                  ActiveRecord::Base.descendants.select { |model| model.respond_to?(:migranize_fields) }
                else
                  []
                end
            end

            def table_exists?(table_name)
              if defined?(ActiveRecord::Base)
                begin
                  conn = ActiveRecord::Base.connection
                  tables = conn.tables
                  
                  # puts "Tables in database: #{tables.join(', ')} (#{tables.count} tables)"
                  
                  exists = tables.include?(table_name)
                  
                  # puts "Table #{table_name} #{exists ? 'exists' : 'does not exist'}"
                  
                  return exists
                rescue => e
                  Migranize.logger.error "Error checking if table #{table_name} exists: #{e.message}"
                  Migranize.logger.error e.backtrace.first
                  return false
                end
              else
                Migranize.logger.error "ActiveRecord not defined"
                return false
              end
            end
              
            def column_exists?(table_name, column_name)
                ActiveRecord::Base.connection.column_exists?(table_name, column_name)
            end
              
            def get_table_columns(table_name)
                ActiveRecord::Base.connection.columns(table_name)
            end

            def compatible_type?(table_name, column_name, model_type)
                column = ActiveRecord::Base.connection.columns(table_name).find { |c| c.name == column_name }
                return false unless column
                
                db_type = rails_type_to_model_type(column.type)
                db_type == model_type.to_sym
              end

            def rails_type_to_model_type(rails_type)
                case rails_type.to_sym
                    when :string, :text
                    :string
                    when :integer
                    :integer
                    when :float, :decimal
                    :float
                    when :boolean
                    :boolean
                    when :date, :datetime, :time
                    :datetime
                    else
                    rails_type.to_sym
                end
            end
        end
    end
end