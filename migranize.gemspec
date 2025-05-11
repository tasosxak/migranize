# frozen_string_literal: true

require_relative "lib/migranize/version"

Gem::Specification.new do |spec|
  spec.name = "migranize"
  spec.version = Migranize::VERSION
  spec.authors = ["tasosxak"]
  spec.email = ["tasosxak@proton.me"]

  spec.summary = "Automatically generate Rails migration files by analyzing model changes"
  spec.description = "Migranize is a Ruby gem that automatically generates migration files for Rails by analyzing changes in your models, similar to Django's migration system. Simply run the generator and then rails db:migrate."
  spec.homepage = "https://github.com/tasosxak/migranize"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ examples/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "bin"
  spec.executables = ["migranize"]
  spec.require_paths = ["lib"]

  spec.add_dependency "rails", ">= 6.0"
  spec.add_dependency "thor", "~> 1.2"
  spec.add_dependency "colorize"
end
