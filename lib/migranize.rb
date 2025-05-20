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

# Migranize is the main module that encapsulates configuration and utilities
# for the Migranize system. It provides a DSL for setting configuration and
# exposes root and logger accessors.
module Migranize
  # Custom error class for all Migranize-specific errors
  class Error < StandardError; end

  class << self
    # @return [Migranize::Configuration] The configuration instance
    attr_accessor :configuration

    # Configures the Migranize module using a block.
    #
    # @example
    #   Migranize.configure do |config|
    #     config.some_option = true
    #   end
    #
    # @yield [configuration] yields the current configuration
    def configure
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?
    end

    # Returns the root path of the application, defaulting to current directory.
    #
    # @return [String] the root path
    def root
      @root || Dir.pwd
    end

    # Sets the root path for the application.
    #
    # @param path [String] the path to be used as root
    def root=(path)
      @root = path
    end

    # Provides a default logger instance.
    #
    # @return [Logger] the logger instance
    def logger
      @logger ||= Logger.new(STDOUT)
    end
  end

  # Automatically initializes the configuration on load
  configure
end