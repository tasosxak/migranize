module Migranize
  module FieldDefinition
    extend ActiveSupport::Concern
      
    class_methods do
      def field(name, type, options = {})
        name = name.to_sym
        migranize_fields[name] = Migranize::Field.new(name, type, options)
      end

      def belongs_to(name, *args, **options, &block)
        foreign_key = options[:foreign_key] || "#{name}_id"

        unless migranize_fields.key?(foreign_key.to_sym)
          options_for_field = { index: true }
          options_for_field[:null] = options[:optional] != true

          field(foreign_key, :integer, options_for_field)
        end

        migranize_relations[:belongs_to] ||= {}
        migranize_relations[:belongs_to][name.to_sym] = options.merge(foreign_key: foreign_key)

        super
      end

      def has_one(name, *args, **options, &block)
        migranize_relations[:has_one] ||= {}
        migranize_relations[:has_one][name.to_sym] = options

        super
      end

      def has_many(name, *args, **options, &block)
        migranize_relations[:has_many] ||= {}
        migranize_relations[:has_many][name.to_sym] = options

        super
      end

      def has_and_belongs_to_many(name, *args, **options, &block)
        migranize_relations[:has_and_belongs_to_many] ||= {}
        migranize_relations[:has_and_belongs_to_many][name.to_sym] = options
        
        super
      end
        
      def migranize_fields
        @migranize_fields ||= {}
      end

      def migranize_relations
        @migranize_relations ||= {}
      end
    end
  end
end