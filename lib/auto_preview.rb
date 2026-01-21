# frozen_string_literal: true

require_relative "auto_preview/version"
require_relative "auto_preview/mock_context"
require_relative "auto_preview/compiler"
require_relative "auto_preview/branch_analyzer"
require_relative "auto_preview/erb_analyzer"
require_relative "auto_preview/coverage_runner"
require_relative "auto_preview/renderer"

module AutoPreview
  class Error < StandardError; end

  # Container for compiled template classes
  module CompiledTemplates; end

  class << self
    # Render an ERB file at the given path, automatically mocking any undefined dependencies
    #
    # @param file_path [String] Path to the ERB file
    # @param locals [Hash] Optional hash of local variables to make available in the template
    # @param mock_values [Hash] Optional hash of specific mock values for methods/variables
    # @return [String] The rendered ERB output
    def render(file_path, locals: {}, mock_values: {})
      Renderer.new(file_path, locals: locals, mock_values: mock_values).render
    end

    # Render an ERB string directly
    #
    # @param erb_string [String] The ERB template string
    # @param locals [Hash] Optional hash of local variables to make available in the template
    # @param mock_values [Hash] Optional hash of specific mock values for methods/variables
    # @return [String] The rendered ERB output
    def render_string(erb_string, locals: {}, mock_values: {})
      Renderer.new(nil, erb_string: erb_string, locals: locals, mock_values: mock_values).render
    end

    # Verify that an ERB template can achieve 100% branch coverage
    # Compiles the template to disk and runs all permutations
    #
    # @param file_path [String] Path to the ERB file
    # @return [CoverageRunner] The coverage runner with results
    def verify_coverage(file_path)
      compiler = Compiler.new(source_path: file_path)
      compiler.compile

      runner = CoverageRunner.new(compiler)
      runner.run
      runner
    end

    # Verify coverage for an ERB string
    #
    # @param erb_string [String] The ERB template string
    # @return [CoverageRunner] The coverage runner with results
    def verify_coverage_string(erb_string)
      compiler = Compiler.new(erb_string: erb_string)
      compiler.compile

      runner = CoverageRunner.new(compiler)
      runner.run
      runner
    end

    # Compile an ERB file to Ruby without running coverage
    #
    # @param file_path [String] Path to the ERB file
    # @return [String] Path to the compiled Ruby file
    def compile(file_path)
      compiler = Compiler.new(source_path: file_path)
      compiler.compile
    end

    # Clean up all compiled templates
    def clean_compiled!
      FileUtils.rm_rf(Compiler.compiled_dir)
    end
  end
end
