# frozen_string_literal: true

require_relative "lib/pg_statistics_rails/version"

Gem::Specification.new do |spec|
  spec.name = "pg-statistics-rails"
  spec.version = PgStatisticsRails::VERSION
  spec.authors = ["Andrew Fader"]
  spec.email = ["fader@yagni.co"]

  spec.summary = "PostgreSQL extended statistics (CREATE STATISTICS) support for Active Record migrations and schema.rb"
  spec.description = <<~DESC.strip
    Adds create_statistics, drop_statistics, and statistics introspection to the
    Active Record PostgreSQL adapter, with reversible migration support and
    automatic schema.rb dumping so extended statistics survive db:schema:load.
  DESC
  spec.homepage = "https://github.com/andrewfader/pg-statistics-rails"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(__dir__) do
    Dir["lib/**/*.rb", "README.md", "LICENSE.txt", "CHANGELOG.md"]
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord", ">= 7.1"
  spec.add_dependency "activesupport", ">= 7.1"
end
