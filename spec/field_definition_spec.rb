require "migranize/field_definition"
require "migranize/field"

RSpec.describe Migranize::FieldDefinition do
  let(:base_class) do
      Class.new do
          def self.belongs_to(*args, **kwargs); end
          def self.has_one(*args, **kwargs); end
          def self.has_many(*args, **kwargs); end
          def self.has_and_belongs_to_many(*args, **kwargs); end
        end
    end

    let(:dummy_class) do
        Class.new(base_class) do
            extend Migranize::FieldDefinition::ClassMethods
        end
    end

  describe ".field" do
    it "adds a field to migranize_fields" do
      dummy_class.field(:title, :string, null: false)
      field = dummy_class.migranize_fields[:title]

      expect(field).to be_a(Migranize::Field)
      expect(field.name).to eq(:title)
      expect(field.type).to eq(:string)
      expect(field.options).to include(null: false)
    end
  end

  describe "association macros" do
    describe ".belongs_to" do
      it "adds foreign key field if not present" do
        dummy_class.belongs_to(:author, optional: true)

        expect(dummy_class.migranize_fields).to have_key(:author_id)
        fk = dummy_class.migranize_fields[:author_id]
        expect(fk.type).to eq(:integer)
        expect(fk.options[:index]).to eq(true)
        expect(fk.options[:null]).to eq(false)
      end
    end

    describe ".has_one" do
      it "registers has_one relation" do
        dummy_class.has_one(:profile, dependent: :destroy)

        expect(dummy_class.migranize_relations[:has_one]).to include(profile: { dependent: :destroy })
      end
    end

    describe ".has_many" do
      it "registers has_many relation" do
        dummy_class.has_many(:comments)

        expect(dummy_class.migranize_relations[:has_many]).to include(:comments)
      end
    end

    describe ".has_and_belongs_to_many" do
      it "registers has_and_belongs_to_many relation" do
        dummy_class.has_and_belongs_to_many(:tags)

        expect(dummy_class.migranize_relations[:has_and_belongs_to_many]).to include(:tags)
      end
    end
  end

  describe ".migranize_fields" do
    it "returns a memoized hash" do
      expect(dummy_class.migranize_fields).to be_a(Hash)
      expect(dummy_class.migranize_fields).to equal(dummy_class.migranize_fields)
    end
  end

  describe ".migranize_relations" do
    it "returns a memoized hash" do
      expect(dummy_class.migranize_relations).to be_a(Hash)
      expect(dummy_class.migranize_relations).to equal(dummy_class.migranize_relations)
    end
  end
end