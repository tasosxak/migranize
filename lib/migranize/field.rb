module Migranize
    class Field
        COMMON_TYPES = [:string, :text, :integer, :float, :decimal, :boolean, :date, :time, :datetime, :binary]
        POSTGRESQL_TYPES = [:uuid, :json, :jsonb, :hstore, :inet, :cidr, :macaddr, :xml, :tsvector, :point, :line, :polygon]
        MYSQL_TYPES = [:tinyint, :mediumint, :bigint, :tinytext, :mediumtext, :longtext, :enum]
        SQLITE_TYPES = []
   
        attr_reader :name, :type, :options, :relation

        def initialize(name, type, options = {})
            @name = name.to_sym
            @type = validate_type(type)
            @options = options

            detect_relation
        end

        def validate_type(type)
            type = type.to_sym
            db_adapter = detect_database_adapter
            
            valid_types = COMMON_TYPES + 
                            (db_adapter == :postgresql ? POSTGRESQL_TYPES : []) +
                            (db_adapter == :mysql ? MYSQL_TYPES : []) +
                            (db_adapter == :sqlite ? SQLITE_TYPES : [])

            unless valid_types.include?(type)
                raise ArgumentError, "Invalid field type: #{type} for #{db_adapter}.\nValid types are: #{valid_types.join(', ')}"
            end
            
            type
        end

        def detect_database_adapter
            if defined?(ActiveRecord::Base) && ActiveRecord::Base.connected?
                case ActiveRecord::Base.connection.adapter_name.downcase
                when /postgresql/
                    :postgresql
                when /mysql/
                    :mysql
                when /sqlite/
                    :sqlite
                else
                    :other
                end
            else
                :other
            end
        end

        def detect_relation
            if name.to_s.end_with?('_id')
                @relation = {
                    type: :belongs_to,
                    model: name.to_s.gsub(/_id$/, '').classify,
                    foreign_key: name
                }
            end
        end

        def relation?
            !@relation.nil?
        end


        def sql_type_for_adapter
            db_adapter = detect_database_adapter
            case db_adapter
            when :postgresql
                postgresql_type_mapping
            when :mysql
                mysql_type_mapping
            else
                common_type_mapping
            end
        end

        def to_hash
            {
                name: name,
                type: type,
                options: options
            }
        end

        def ==(other)
            return false unless other.is_a?(Field)

            name == other.name && type == other.type
        end

        def similar?(other)
            return false unless other.is_a?(Field)
            
            name == other.name
        end

        private

        def postgresql_type_mapping
            case type
            when :string
                "varchar(#{options[:limit] || 255})"
            when :decimal
                precision = options[:precision] || 10
                scale = options[:scale] || 0
                "decimal(#{precision}, #{scale})"
            when :uuid
                "uuid"
            when :json
                "json"
            when :jsonb
                "jsonb"
            else
                type.t_s
            end
        end

        def mysql_type_mapping
            case type
            when :string
                "varchar(#{options[:limit] || 255})"
            when :text
                if options[:limit]
                    if options[:limit] < 256
                        "tinytext"
                    elsif options[:limit] < 65536
                        "text"
                    elsif options[:limit] < 16777216
                        "mediumtext"
                    else
                        "longtext"
                    end
                else
                    "text"
                end
            else
                type.to_s
            end
        end

        def common_type_mapping
            type.to_s
        end
    end
end