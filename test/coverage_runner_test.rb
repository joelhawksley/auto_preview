# frozen_string_literal: true

require "test_helper"

class CoverageRunnerTest < Minitest::Test
  include TestHelper

  def setup
    AutoPreview.clean_compiled!
  end

  def teardown
    AutoPreview.clean_compiled!
  end

  def test_blocked_variable_detection
    # Create a template with a "_blocked" variable to test line 88
    erb = <<~ERB
      <% if user_blocked %>
        Blocked user
      <% else %>
        Active user
      <% end %>
    ERB
    
    # Write temporary erb file
    temp_path = File.join(Dir.tmpdir, "blocked_test_#{$$}.erb")
    File.write(temp_path, erb)
    
    begin
      compiler = AutoPreview::Compiler.new(source_path: temp_path)
      compiler.compile
      runner = AutoPreview::CoverageRunner.new(compiler)
      runner.run
      
      # Just verify it runs without error
      assert runner.results
    ensure
      File.delete(temp_path) if File.exist?(temp_path)
    end
  end

  def test_default_coverage_values
    compiler = AutoPreview::Compiler.new(source_path: fixture_path("simple.erb"))
    compiler.compile
    runner = AutoPreview::CoverageRunner.new(compiler)
    
    # Access the default_coverage method via send since it's private
    default = runner.send(:default_coverage)
    
    assert_equal 0.0, default[:line_coverage]
    assert_equal 0.0, default[:branch_coverage]
    assert_equal 0, default[:lines_total]
    assert_equal [], default[:uncovered_lines]
  end

  def test_subprocess_error_handling
    compiler = AutoPreview::Compiler.new(source_path: fixture_path("simple.erb"))
    compiler.compile
    runner = AutoPreview::CoverageRunner.new(compiler)
    runner.analyzer.analyze
    runner.erb_analyzer.analyze
    
    # Mock Open3.capture3 to simulate a subprocess failure
    Open3.stub :capture3, ["", "Simulated error", OpenStruct.new(success?: false)] do
      result = runner.send(:run_in_subprocess, [{}])
      assert_equal false, result[:outputs].first[:success]
      assert_equal "Simulated error", result[:outputs].first[:error]
      assert_equal 0.0, result[:coverage][:line_coverage]
    end
  end
end
