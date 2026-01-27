# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"].exclude("test/standalone/**/*")
end

Rake::TestTask.new(:test_coverage_unit) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/standalone/coverage_tracker_test.rb"]
  t.description = "Run coverage tracker unit tests (standalone, no SimpleCov)"
end

Rake::TestTask.new(:test_coverage_system) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/standalone/coverage_system_test.rb"]
  t.description = "Run coverage highlighting system tests (standalone, no SimpleCov)"
end

task test_coverage: [:test_coverage_unit, :test_coverage_system]

task default: :test
