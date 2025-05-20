# spec/migranize_spec.rb
require "spec_helper"
require "migranize"

RSpec.describe Migranize do
  describe ".configure" do
    it "yields the configuration object" do
      expect { |block| described_class.configure(&block) }.to yield_with_args(Migranize::Configuration)
    end

    it "allows setting configuration migrations_dir" do
      described_class.configure do |config|
        config.migrations_dir = "test/migrate"
      end

      expect(described_class.configuration.migrations_dir).to eq("test/migrate")
    end

    it "allows setting configuration models_dir" do
      described_class.configure do |config|
        config.models_dir = "test/models"
      end

      expect(described_class.configuration.models_dir).to eq("test/models")
    end

    it "allows setting configuration ignore_tables" do
      described_class.configure do |config|
        config.ignore_tables = ['MyClass']
      end

      expect(described_class.configuration.ignore_tables).to include('MyClass')
    end

    it "allows setting configuration ignore_namespaces" do
      described_class.configure do |config|
        config.ignore_namespaces = ['MyNamespace']
      end

      expect(described_class.configuration.ignore_namespaces).to include('MyNamespace')
    end

    it "initializes configuration if not set" do
      described_class.configuration = nil
      described_class.configure {}

      expect(described_class.configuration).to be_a(Migranize::Configuration)
    end
  end

  describe ".root" do
    after do
      described_class.root = nil # reset after test
    end

    it "returns the current directory by default" do
      expect(described_class.root).to eq(Dir.pwd)
    end

    it "can be set manually" do
      path = "/tmp/some_path"
      described_class.root = path
      expect(described_class.root).to eq(path)
    end
  end

  describe ".logger" do
    before do
      described_class.instance_variable_set(:@logger, nil)
    end

    it "returns a Logger instance" do
      expect(described_class.logger).to be_a(Logger)
    end

    it "memoizes the logger instance" do
      logger1 = described_class.logger
      logger2 = described_class.logger
      expect(logger1.object_id).to eq(logger2.object_id)
    end
  end
end