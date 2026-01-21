# frozen_string_literal: true

require "simplecov"
SimpleCov.enable_coverage(:branch)
SimpleCov.start do
  enable_coverage_for_eval
  
  # Filter out test files but keep fixtures
  add_filter do |source_file|
    source_file.filename.include?("/test/") && 
      !source_file.filename.include?("/test/fixtures/")
  end
  add_filter "lib/auto_preview/version.rb"  # version.rb is loaded before SimpleCov by gemspec
  
  # Track both library code and ERB fixtures
  # Note: ERB fixture coverage is informational only - some lines may show as
  # uncovered due to how ActionView compiles ERB to Ruby. The actual test
  # assertions verify the code runs correctly.
  track_files "{lib/**/*.rb,test/fixtures/**/*.erb}"
  
  # Group results for better visibility
  add_group "Library", "lib/"
  add_group "Fixtures", "test/fixtures/"
  
  # Apply minimum coverage only to library code
  # Fixtures are test data and don't need 100% coverage
  minimum_coverage_by_file line: 0, branch: 0  # Don't fail on individual files
end

# After SimpleCov runs, check library coverage manually
SimpleCov.at_exit do
  SimpleCov.result.format!
  
  # Check library group coverage
  library_group = SimpleCov.result.groups["Library"]
  if library_group
    line_coverage = library_group.covered_percent
    branch_coverage = if library_group.total_branches > 0
      (library_group.covered_branches.to_f / library_group.total_branches * 100).round(2)
    else
      100.0
    end
    
    if line_coverage < 100.0
      warn "Library line coverage (#{line_coverage}%) is below 100%"
      exit 2
    end
    
    if branch_coverage < 100.0
      warn "Library branch coverage (#{branch_coverage}%) is below 100%"
      exit 2
    end
  end
end

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "auto_preview"
require "ostruct"
require "minitest/autorun"

module TestHelper
  def fixtures_path
    File.expand_path("fixtures", __dir__)
  end

  def fixture_path(name)
    File.join(fixtures_path, name)
  end
end
