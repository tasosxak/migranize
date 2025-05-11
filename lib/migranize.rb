# frozen_string_literal: true

require "active_support/all"
require "migranize/version"
require "migranize/field"
require "migranize/field_definition"
require "migranize/schema_comparator"
require "migranize/migration/generator"
require "migranize/cli"
require "migranize/configuration"
require "thor"

require "migranize/railtie" if defined?(Rails)

module Migranize
  class Error < StandardError; end
  
  class << self
    attr_accessor :configuration

    def configure
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?
    end
    
    def root
      @root || Dir.pwd
    end

    def root=(path)
      @root = path
    end

    def logger
      @logger ||= Logger.new(STDOUT)
    end
  end

  configure
end
