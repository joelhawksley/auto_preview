# frozen_string_literal: true

require "coverage"

module AutoPreview
  # :nocov:
  # Tracks line coverage for ERB template rendering using Ruby's Coverage module
  # with eval coverage support (Ruby 3.2+)
  module CoverageTracker
    class << self
      def track(template_path, view_paths, &block)
        # Skip coverage tracking in test environment (conflicts with SimpleCov)
        if ENV["RAILS_ENV"] == "test" || ENV["RACK_ENV"] == "test"
          return [{}, block.call]
        end

        # Find the full template file path
        full_path = view_paths
          .map { |vp| File.join(vp, template_path) }
          .find { |fp| File.exist?(fp) }

        return [{}, block.call] unless full_path

        # Resolve to absolute path for matching
        absolute_path = File.expand_path(full_path)

        # Clear the template cache so the template gets recompiled
        # This is necessary for Coverage to see the eval'd code
        ActionView::LookupContext::DetailsKey.clear if defined?(ActionView::LookupContext::DetailsKey)
        ActionView::Resolver.caching = false if defined?(ActionView::Resolver)

        # Start coverage with eval support (Ruby 3.2+)
        # This tracks code evaluated via Kernel#eval, which ERB uses
        Coverage.start(lines: true, eval: true)

        result = nil
        coverage_data = nil
        begin
          result = block.call
        ensure
          coverage_data = Coverage.result
        end

        # Extract coverage for our template
        line_coverage = extract_template_coverage(coverage_data, absolute_path, template_path)

        [line_coverage, result]
      end

      private

      def extract_template_coverage(coverage_data, absolute_path, template_path)
        line_coverage = {}

        # Look for coverage data matching our template
        # With eval coverage, ERB sets the filename to the template path
        coverage_data.each do |file_path, data|
          # Match by absolute path, relative path, or template name
          if file_path == absolute_path ||
             file_path.end_with?(template_path) ||
             file_path.include?(template_path)

            lines = data.is_a?(Hash) ? data[:lines] : data
            next unless lines

            lines.each_with_index do |count, index|
              line_num = index + 1
              next if count.nil? # Line is not executable (comments, blank, HTML-only, etc.)

              line_coverage[line_num] = count > 0
            end
          end
        end

        line_coverage
      end
    end
  end
  # :nocov:
end
