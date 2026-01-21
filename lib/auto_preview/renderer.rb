# frozen_string_literal: true

require "erb"
require "fileutils"

module AutoPreview
  class Renderer
    attr_reader :file_path, :erb_string, :locals, :mock_values, :context

    # Directory for compiled ERB files - use a project-local directory for coverage
    COMPILED_DIR = File.expand_path("../../../tmp/compiled_erb", __dir__)

    def initialize(file_path, erb_string: nil, locals: {}, mock_values: {})
      @file_path = file_path
      @erb_string = erb_string
      @locals = locals
      @mock_values = mock_values
      @context = nil

      validate!
    end

    def render
      template = load_template
      @context = MockContext.new(locals: locals, mock_values: mock_values)
      
      erb = ERB.new(template, trim_mode: "-")
      erb.filename = file_path if file_path
      erb.result(context.get_binding)
    end

    # Returns the list of mocked methods/variables that were accessed during rendering
    def accessed_mocks
      @context&.accessed_mocks || []
    end

    private

    def validate!
      if file_path.nil? && erb_string.nil?
        raise Error, "Either file_path or erb_string must be provided"
      end

      if file_path && !File.exist?(file_path)
        raise Error, "File not found: #{file_path}"
      end
    end

    def load_template
      if erb_string
        erb_string
      else
        File.read(file_path)
      end
    end
  end
end
