module Migranize
    module Migration
        class Generator
            class << self
                def generate_for_all_models
                    changes_by_model = SchemaComparator.compare_all_models

                    return false if changes_by_model.empty?

                    timestamp = Time.now.strftime("%Y%m%d%H%M%S")
                    migration_content = build_migration_content(changes_by_model, timestamp)

                    write_migration_file(timestamp, migration_content)

                    true
                end

                def migration_file_name
                    @migration_file_name ||= []
                end

                private

                def build_migration_content(changes_by_model, timestamp)
                    content = [ "# Migration generated at #{Time.now}\n" ]
                    content << []
                    content << "\tdef change\n"
                    
                    changes_by_model.each do |model_class, changes|
                      table_name = model_class.table_name
                      
                      if !table_exists?(table_name)
                        content << create_table_definition(model_class, table_name)
                      else
                        content << alter_table_definition(model_class, table_name, changes)
                      end
                    end

                    # changes_by_model.each do |model_class, changes|
                    #  table_name = model_class.table_name
                    #
                    #  content << add_indexes_and_foreign_keys(model_class, table_name)
                    # end
            
                    content << "\tend\n"
                    content << "end\n"
                    content[1] = "class #{migration_file_name.take(4).join("_").camelize} < ActiveRecord::Migration[7.0]\n"
            
                    content.join
                  end

                def rails_options_string(options)
                    return "" if options.empty?
                    
                    parts = []
                    options.each do |key, value|
                      rails_key = case key.to_sym
                                 when :default
                                   :default
                                 when :null
                                   :null
                                 else
                                   key.to_sym
                                 end
                      
                      parts << "#{rails_key}: #{ruby_value_literal(value)}"
                    end
                    
                    ", " + parts.join(", ")
                  end
                  
                  def ruby_value_literal(value)
                    case value
                    when Proc
                      value.call.inspect
                    when String
                      value.inspect
                    when Symbol
                      value.inspect
                    when TrueClass, FalseClass, NilClass
                      value.inspect
                    else
                      value.to_s
                    end
                  end

                def write_migration_file(timestamp, content)
                    migrations_dir = Migranize.configuration.migrations_dir                    
                    FileUtils.mkdir_p(migrations_dir)

                    file_path = File.join(migrations_dir, "#{timestamp}_#{migration_file_name.take(4).join("_")}.rb")
                    File.write(file_path, content)
                    
                    # Migranize.logger.info "Migration generated at: #{file_path}"
                    
                    file_path
                  end
                
                  private

                  def table_exists?(table_name)
                    if defined?(ActiveRecord::Base) && ActiveRecord::Base.connected?
                      ActiveRecord::Base.connection.table_exists?(table_name)
                    else
                      false
                    end
                  end

                  def index_exists?(table_name, column_name, options = {})
                    if defined?(ActiveRecord::Base) && ActiveRecord::Base.connected?
                      if ActiveRecord::Base.connection.respond_to?(:index_exists_on?)
                        ActiveRecord::Base.connection.index_exists_on?(table_name, column_name, options)
                      else
                        begin
                          ActiveRecord::Base.connection.index_exists?(table_name, column_name, options)
                        rescue ArgumentError
                          ActiveRecord::Base.connection.index_exists?(table_name, column_name)
                        end
                      end
                    else
                      false
                    end
                  end

                  def foreign_key_exists?(from_table, to_table, options = {})
                    if defined?(ActiveRecord::Base) && ActiveRecord::Base.connected?
                      column = options[:column] || "#{to_table.to_s.singularize}_id"
                      
                      foreign_keys = ActiveRecord::Base.connection.foreign_keys(from_table.to_s)
                      foreign_keys.any? do |fk|
                        fk.to_table.to_s == to_table.to_s && fk.options[:column].to_s == column.to_s
                      end
                    else
                      false
                    end
                  end

                  def create_table_definition(model_class, table_name)
                    migration_file_name << "create"
                    migration_file_name << table_name
                    content = []
                    
                    content << "\tcreate_table :#{table_name} do |t|\n"
                    model_class.migranize_fields.each do |name, field|
                      options_str = rails_options_string(field.options)
                      content << "\t\tt.#{field.type} :#{field.name}#{options_str}\n"
                    end
                    
                    content << "\t\tt.timestamps\n"
                    content << "\tend\n\n"

                    model_class.migranize_fields.each do |name, field|
                      #if field.options[:index] || field.relation?
                      #  if !index_exists?(table_name, field.name)
                      #    content << "\tadd_index :#{table_name}, :#{field.name}\n"
                      #  end
                      #end
                      
                      if field.relation?
                        referenced_table = field.relation[:model].underscore.pluralize
                        if !foreign_key_exists?(table_name, referenced_table, column: field.name)
                          content << "\tadd_foreign_key :#{table_name}, :#{referenced_table}, column: :#{field.name}\n"
                        end
                      end
                    end
                    
                    content << "\n"
                    content.join
                  end

                  def alter_table_definition(model_class, table_name, changes)
                    content = []

                    changes[:add_fields].each do |field|
                      migration_file_name << "add"
                      migration_file_name << field.name
                      options_str = rails_options_string(field.options)
                      content << "\tadd_column :#{table_name}, :#{field.name}, :#{field.type}#{options_str}\n"

                      if field.options[:index] || field.relation?
                        if !index_exists?(table_name, field.name)
                          content << "    add_index :#{table_name}, :#{field.name}\n"
                        end
                      end
                      
                      if field.relation?
                        referenced_table = field.relation[:model].underscore.pluralize
                        if !foreign_key_exists?(table_name, referenced_table, column: field.name)
                          content << "    add_foreign_key :#{table_name}, :#{referenced_table}, column: :#{field.name}\n"
                        end
                      end
                    end
                    
                    changes[:change_fields].each do |field|
                      migration_file_name << "change"
                      migration_file_name << field.name
                      options_str = rails_options_string(field.options)
                      content << "\tchange_column :#{table_name}, :#{field.name}, :#{field.type}#{options_str}\n"
                    end
                    
                    changes[:remove_fields].each do |field|
                      migration_file_name << "delete"
                      migration_file_name << field.name
                      content << "\tremove_column :#{table_name}, :#{field.name}\n"
                    end

                    content <<"\n" unless content.empty?
                    content.join
                  end

                  def add_indexes_and_foreign_keys(model_class, table_name)
                    content = []

                    model_class.migranize_fields.each do |name, field|
                      if field.options[:index] || field.relation?
                        content << "\tadd_index :#{table_name}, :#{field.name}\n"
                      end
                    end

                    model_class.migranize_fields.each do |name, field|
                      if field.relation?
                        referenced_table = field.relation[:model].underscore.pluralize
                        content << "\tadd_foreign_key :#{table_name}, :#{referenced_table}, column: :#{field.name}\n"
                      end
                    end

                    content.join
                  end

                def create_join_tables(changes_by_model)
                  content = []
                  join_tables = []
                  
                  content << "\n"
                  
                  changes_by_model.each do |model_class, _|
                    if model_class.respond_to?(:migranize_relations) && model_class.migranize_relations[:has_and_belongs_to_many]
                      model_class.migranize_relations[:has_and_belongs_to_many].each do |association_name, options|
                        join_table_name = options[:join_table]

                        unless join_table_name
                          associated_class_name = options[:class_name] || association_name.to_s.classify
                          tables = [model_class.table_name, associated_class_name.underscore.pluralize].sort
                          join_table_name = tables.join('_')
                        end

                        next if join_tables.include?(join_table_name)
                        join_tables << join_table_name

                        unless table_exists?(join_table_name)
                          model_key = "#{model_class.name.underscore.signularize}_id"
                          association_key = "#{association_name.to_s.signularize}_id"

                          content << "\tcreate_table :#{join_table_name}, id: false do |t|\n"
                          content << "\t\tt.references :#{model_class.name.underscore.signularize}, foreign_key: true\n"
                          content << "\t\tt.references :#{association_name.to_s.signularize}, foreign_key: true\n"
                          content << "\t\tt.index [#{model_key}, #{association_key}], unique: true\n"
                          content << "\tend\n\n"
                        end
                      end
                    end
                  end

                  content.join
                end
            end
        end
    end
end