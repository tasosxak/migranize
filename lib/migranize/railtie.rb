module Migranize
    class Railtie < Rails::Railtie
      initializer "migranize.initialize" do
        ActiveSupport.on_load(:active_record) do
          ActiveRecord::Base.extend(Migranize::FieldDefinition::ClassMethods)
        end
      end
    end
end