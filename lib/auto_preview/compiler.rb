# frozen_string_literal: true

require "erb"
require "fileutils"
require "tmpdir"
require "action_view"

module AutoPreview
  # Compiles ERB templates to Ruby files on disk for coverage tracking
  class Compiler
    attr_reader :source_path, :compiled_path, :erb_source

    # Directory for compiled ERB files - compute at runtime to handle gem installation
    def self.compiled_dir
      @compiled_dir ||= File.join(Dir.tmpdir, "auto_preview_compiled")
    end

    def self.compiled_dir=(path)
      @compiled_dir = path
    end

    def initialize(source_path: nil, erb_string: nil)
      @source_path = source_path
      @erb_string = erb_string
      @erb_source = load_source
      @compiled_path = nil
    end

    def compile
      FileUtils.mkdir_p(self.class.compiled_dir)

      # Generate a stable filename based on source path or content hash
      filename = if source_path
        File.basename(source_path, ".*")
      else
        "string_#{@erb_source.hash.abs}"
      end

      @compiled_path = File.join(self.class.compiled_dir, "#{filename}.rb")

      # Use ActionView's ERB handler to compile - it handles Rails-specific syntax better
      erb_src = compile_with_actionview
      
      # Transform ||= patterns to use __auto_preview_local for mock injection
      # This allows us to control local variable values from the context
      erb_src = transform_local_assigns(erb_src)

      # Write the compiled template as a Ruby file
      # We require const_stub at the top to provide the create_const_stub helper
      const_stub_path = File.expand_path("const_stub", __dir__)
      
      ruby_code = <<~RUBY
        # frozen_string_literal: true
        # Compiled from: #{source_path || '(string)'}
        # Generated at: #{Time.now.iso8601}

        require #{const_stub_path.inspect}
        
        module AutoPreview
          module CompiledTemplates
            class #{class_name}
              # Auto-create stub constants for undefined references
              def self.const_missing(name)
                stub = AutoPreview::CompiledTemplates.create_const_stub(self.name)
                const_set(name, stub)
                stub
              end
              
              def self.render(__context__)
                __context__.instance_eval do
                  #{erb_src}
                end
              end
            end
          end
        end
      RUBY

      File.write(@compiled_path, ruby_code)
      @compiled_path
    end

    def class_name
      @class_name ||= begin
        base = if source_path
          File.basename(source_path, ".*")
        else
          "String#{@erb_source.hash.abs}"
        end
        "Template_#{base.gsub(/[^a-zA-Z0-9]/, '_')}"
      end
    end

    def template_class
      AutoPreview::CompiledTemplates.const_get(class_name)
    end

    private

    def compile_with_actionview
      # Create a mock template object for ActionView handler
      template = MockTemplate.new(@erb_source, source_path || "(string)")
      handler = ActionView::Template.handler_for_extension(:erb)
      handler.call(template, @erb_source)
    end

    # Transform ||= patterns to use __auto_preview_local for mock injection
    # Pattern: "varname ||= default_value" becomes "varname = __auto_preview_local(:varname, -> { default_value })"
    # This allows the context to inject mock values for local variables
    def transform_local_assigns(erb_src)
      # Match patterns like: "  issue                    ||= nil"
      # or: "comment ||= starting_comment"
      erb_src.gsub(/^(\s*)([a-z_][a-z0-9_]*)\s*\|\|=\s*(.+)$/i) do |match|
        indent = $1
        var_name = $2
        default_expr = $3.strip
        "#{indent}#{var_name} = __auto_preview_local(:#{var_name}, -> { #{default_expr} })"
      end
    end

    # Mock template object for ActionView handler
    class MockTemplate
      attr_reader :source, :identifier

      def initialize(source, identifier)
        @source = source
        @identifier = identifier
      end

      def type
        :html
      end
    end

    def load_source
      if @erb_string
        @erb_string
      elsif source_path && File.exist?(source_path)
        File.read(source_path)
      else
        raise Error, "Either source_path or erb_string must be provided"
      end
    end
  end
end
