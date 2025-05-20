# spec/schema_comparator_spec.rb
require 'spec_helper'
require 'active_record'

class ApplicationRecord
end

class TestA < ApplicationRecord
end

class TestB
end

RSpec.describe Migranize::SchemaComparator do
  before do
    stub_const("TestModelA", TestA.new)
    stub_const("TestModelB", TestB.new)
    allow(TestModelA).to receive(:table_name).and_return("test_models")
  end

  describe ".compare_model_with_db" do
    context "when model does not inherit from ApplicationRecord" do
      it "returns an empty hash" do
        result = described_class.compare_model_with_db(TestModelB)
        expect(result).to eq({})
      end
    end

    context "when model has no migranize_fields" do
      it "returns an empty hash" do
        allow(TestModelA).to receive(:migranize_fields).and_return([])
        result = described_class.compare_model_with_db(TestModelA)
        expect(result).to eq({add_fields: [], change_fields: [], remove_fields: []})
      end
    end

    context "when table does not exist" do
      it "returns all fields as add_fields" do
        allow(TestModelA).to receive(:migranize_fields).and_return({ title: Migranize::Field.new(:title, :string) })
        allow(described_class).to receive(:table_exists?).and_return(false)

        result = described_class.compare_model_with_db(TestModelA)
        expect(result[:add_fields].map(&:name)).to include(:title)
      end
    end

    context "when fields differ from DB" do
      it "detects changed, added, and removed fields" do
        allow(TestModelA).to receive(:migranize_fields).and_return({
          title: Migranize::Field.new(:title, :string),
          views: Migranize::Field.new(:views, :integer)
        })

        mock_column = ->(name, type) { double("Column", name: name.to_s, type: type) }

        allow(described_class).to receive(:table_exists?).and_return(true)
        allow(described_class).to receive(:get_table_columns).and_return([
          mock_column.call("title", :text), # mismatch type
          mock_column.call("old_column", :string)
        ])
        allow(described_class).to receive(:column_exists?).and_return(true, false)
        allow(described_class).to receive(:compatible_type?).with("test_models", "title", :string).and_return(false)

        result = described_class.compare_model_with_db(TestModelA)

        expect(result[:change_fields].map(&:name)).to include(:title)
        expect(result[:add_fields].map(&:name)).to include(:views)
        expect(result[:remove_fields].map(&:name)).to include(:old_column)
      end
    end
  end

  describe ".check_for_unapplied_migrations!" do
    it "raises if unapplied migrations exist" do
      allow(described_class).to receive(:unapplied_migrations).and_return(["20230518123456_create_users.rb"])
      expect {
        described_class.send(:check_for_unapplied_migrations!)
      }.to raise_error(Migranize::PendingMigrationsError, /Pending migrations detected/)
    end

    it "does nothing if no pending migrations" do
      allow(described_class).to receive(:unapplied_migrations).and_return([])
      expect {
        described_class.send(:check_for_unapplied_migrations!)
      }.not_to raise_error
    end
  end

  describe ".unapplied_migrations" do
    it "returns migration files that are not in schema_migrations" do
        allow(Migranize.configuration).to receive(:migrations_dir).and_return("db/migrate")
        allow(Dir).to receive(:glob).with("db/migrate/*.rb").and_return([
        "db/migrate/20230101000000_add_foo.rb",
        "db/migrate/20230102000000_add_bar.rb"
        ])

        # Create a mock connection double
        fake_connection = double("ActiveRecordConnection")
        # Stub the connection method on ActiveRecord::Base to return the mock connection
        allow(ActiveRecord::Base).to receive(:connection).and_return(fake_connection)

        # Stub execute on the mock connection to return applied migrations
        mock_result = [{ "version" => "20230101000000" }]
        allow(fake_connection).to receive(:execute).with("SELECT version FROM schema_migrations").and_return(mock_result)

        result = described_class.send(:unapplied_migrations)
        expect(result).to include("db/migrate/20230102000000_add_bar.rb")
        expect(result).not_to include("db/migrate/20230101000000_add_foo.rb")
    end
   end
end