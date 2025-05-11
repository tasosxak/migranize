require 'colorize'

module Migranize
    class SchemaComparator
        class << self
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
                puts "table name: #{table_name}\n"
                puts "column names: #{db_columns.map(&:name).join(", ")}"

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

            def compare_all_models
                changes_by_model = {}

                ignore_namespaces = Migranize.configuration.ignore_namespaces
                all_models = find_all_ar_models_with_migranize

                all_models.each do |model_class|
                    if ignore_namespaces.any? { |ns| model_class.to_s.start_with?(ns) }
                      # puts "Skipping model #{model_class.to_s} (ignored namespace)"
                      next
                    end
                
                    if Migranize.configuration.ignore_tables.include?(model_class.table_name)
                      # puts "Skipping model #{model_class.to_s} (ignored table: #{model_class.table_name})"
                      next
                    end
                
                    next unless model_has_migranize_fields?(model_class)

                    changes = compare_model_with_db(model_class)

                    if changes[:add_fields].any? || changes[:remove_fields].any? || changes[:change_fields].any?
                      puts "#{model_class.to_s}".bold
                      puts "  Add fields: #{changes[:add_fields].map(&:name).join(', ').bold}".green if changes[:add_fields].any?
                      puts "  Change fields: #{changes[:change_fields].map(&:name).join(', ').bold}".yellow if changes[:change_fields].any?
                      puts "  Remove fields: #{changes[:remove_fields].map(&:name).join(', ').bold}".red if changes[:remove_fields].any?
      
                      changes_by_model[model_class] = changes
                    end
                end

                puts "Found changes for #{changes_by_model.keys.count} models."
                changes_by_model
            end

            private

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
                  puts "Error checking if table #{table_name} exists: #{e.message}"
                  puts e.backtrace.first
                  return false
                end
              else
                puts "ActiveRecord not defined"
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