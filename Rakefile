# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

desc "Run tests with coverage"
task :coverage do
  ENV["COVERAGE"] = "true"
  Rake::Task[:test].invoke
end

task default: :test

desc "Fail when a packaged file is not world-readable"
task :check_permissions do
  unreadable = Bundler::GemHelper.gemspec.files.reject { |file| File.stat(file).mode.anybits?(0o004) }
  abort "Not world-readable, run chmod a+r on: #{unreadable.join(" ")}" if unreadable.any?
end

Rake::Task[:build].enhance([:check_permissions])
