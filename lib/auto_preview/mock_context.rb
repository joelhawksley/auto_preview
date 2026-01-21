# frozen_string_literal: true

require "action_view"
require "active_support/core_ext/string"

module AutoPreview
  # A context object that automatically mocks any undefined method calls
  # This allows ERB templates to render even when dependencies are not available
  class MockContext
    # Creates a new mock value that can respond to any method
    class MockValue
      attr_reader :method_name, :custom_value

      def initialize(method_name = nil, custom_value: nil, has_custom_value: false)
        @method_name = method_name
        @custom_value = custom_value
        @has_custom_value = has_custom_value
      end

      def has_custom_value?
        @has_custom_value
      end

      # Make mock values truthy by default for conditionals
      def !
        false
      end

      # Support boolean coercion
      def to_s
        return @custom_value.to_s if has_custom_value?
        "[mock:#{@method_name || 'value'}]"
      end

      def to_str
        to_s
      end

      def to_a
        return @custom_value.to_a if has_custom_value? && @custom_value.respond_to?(:to_a)
        []
      end

      def to_ary
        to_a
      end

      def to_i
        return @custom_value.to_i if has_custom_value?
        0
      end

      def to_int
        to_i
      end

      def to_f
        return @custom_value.to_f if has_custom_value?
        0.0
      end

      # Support iteration (returns empty by default)
      def each(&block)
        return enum_for(:each) unless block_given?
        if has_custom_value? && @custom_value.respond_to?(:each)
          @custom_value.each(&block)
        end
        self
      end

      def map(&block)
        return enum_for(:map) unless block_given?
        if has_custom_value? && @custom_value.respond_to?(:map)
          @custom_value.map(&block)
        else
          []
        end
      end

      def select(&block)
        return enum_for(:select) unless block_given?
        []
      end

      def empty?
        return @custom_value.empty? if has_custom_value? && @custom_value.respond_to?(:empty?)
        true
      end

      def nil?
        false
      end

      def present?
        true
      end

      def blank?
        false
      end

      def any?
        return @custom_value.any? if has_custom_value? && @custom_value.respond_to?(:any?)
        false
      end

      def length
        return @custom_value.length if has_custom_value? && @custom_value.respond_to?(:length)
        0
      end

      def size
        length
      end

      def count
        length
      end

      def first
        return @custom_value.first if has_custom_value? && @custom_value.respond_to?(:first)
        MockValue.new("#{@method_name}.first")
      end

      def last
        return @custom_value.last if has_custom_value? && @custom_value.respond_to?(:last)
        MockValue.new("#{@method_name}.last")
      end

      def [](key)
        return @custom_value[key] if has_custom_value? && @custom_value.respond_to?(:[])
        MockValue.new("#{@method_name}[#{key.inspect}]")
      end

      # Respond to any method by returning another MockValue
      def method_missing(method_name, *args, &block)
        MockValue.new("#{@method_name}.#{method_name}")
      end

      def respond_to_missing?(method_name, include_private = false)
        true
      end

      # Comparison operators - make mocks work in conditionals
      def ==(other)
        return @custom_value == other if has_custom_value?
        other.is_a?(MockValue)
      end

      def !=(other)
        !(self == other)
      end

      def >(other)
        return @custom_value > other if has_custom_value?
        true
      end

      def <(other)
        return @custom_value < other if has_custom_value?
        false
      end

      def >=(other)
        return @custom_value >= other if has_custom_value?
        true
      end

      def <=(other)
        return @custom_value <= other if has_custom_value?
        true
      end

      def <=>(other)
        return @custom_value <=> other if has_custom_value?
        0
      end

      # Arithmetic operators
      def +(other)
        return @custom_value + other if has_custom_value?
        MockValue.new("#{@method_name}+")
      end

      def -(other)
        return @custom_value - other if has_custom_value?
        MockValue.new("#{@method_name}-")
      end

      def *(other)
        return @custom_value * other if has_custom_value?
        MockValue.new("#{@method_name}*")
      end

      def /(other)
        return @custom_value / other if has_custom_value?
        MockValue.new("#{@method_name}/")
      end

      def %(other)
        return @custom_value % other if has_custom_value?
        MockValue.new("#{@method_name}%")
      end

      def coerce(other)
        [MockValue.new, self]
      end
    end

    def initialize(locals: {}, mock_values: {})
      @locals = locals
      @mock_values = mock_values
      @accessed_mocks = []
      
      # ActionView uses @output_buffer for rendering
      @output_buffer = ActionView::OutputBuffer.new

      # Define local variables as methods
      @locals.each do |name, value|
        name_str = name.to_s
        if name_str.start_with?("@")
          # Handle instance variables
          instance_variable_set(name_str, value)
        else
          # Accept any args to handle method calls like can_modify_issue?(issue)
          define_singleton_method(name) { |*args, **kwargs, &block| value }
        end
      end

      # Define specific mock values as methods
      @mock_values.each do |name, value|
        name_str = name.to_s
        if name_str.start_with?("@")
          instance_variable_set(name_str, value)
        else
          # Accept any args to handle method calls like can_modify_issue?(issue)
          define_singleton_method(name) { |*args, **kwargs, &block| value }
        end
      end
    end

    # Track which mocks were accessed during rendering
    attr_reader :accessed_mocks

    # Used by compiled templates to handle ||= patterns
    # Checks if we have a mock value for the variable, otherwise evaluates the default
    def __auto_preview_local(var_name, default_proc)
      if @mock_values.key?(var_name)
        @mock_values[var_name]
      elsif @mock_values.key?(var_name.to_s)
        @mock_values[var_name.to_s]
      else
        default_proc.call
      end
    end

    # Get the binding for ERB evaluation
    def get_binding
      binding
    end

    # Catch any undefined method and return a mock value
    def method_missing(method_name, *args, &block)
      @accessed_mocks << method_name unless @accessed_mocks.include?(method_name)
      MockValue.new(method_name)
    end

    def respond_to_missing?(method_name, include_private = false)
      true
    end

    # Common Rails/web helpers that might be called
    def content_for(name, content = nil, &block)
      if block_given?
        yield
        ""
      else
        ""
      end
    end

    def capture(&block)
      yield if block_given?
    end

    def concat(string)
      string.to_s
    end

    def raw(string)
      string.to_s
    end

    def html_safe(string)
      string.to_s
    end

    def h(string)
      ERB::Util.html_escape(string.to_s)
    end

    def escape_html(string)
      h(string)
    end

    def link_to(text, url = nil, options = {})
      url ||= "#"
      "<a href=\"#{h(url)}\">#{h(text)}</a>"
    end

    def image_tag(source, options = {})
      "<img src=\"#{h(source)}\" />"
    end

    def render(options = {}, locals = {}, &block)
      if block_given?
        yield
      else
        "[rendered: #{options.inspect}]"
      end
    end

    def t(key, options = {})
      "[translation:#{key}]"
    end
    alias_method :translate, :t

    def l(object, options = {})
      "[localized:#{object}]"
    end
    alias_method :localize, :l

    def pluralize(count, singular, plural = nil)
      count == 1 ? "#{count} #{singular}" : "#{count} #{plural || singular + 's'}"
    end

    def truncate(text, options = {})
      length = options[:length] || 30
      text.to_s[0, length]
    end

    def number_to_currency(number, options = {})
      "$#{number}"
    end

    def time_ago_in_words(time)
      "[time_ago:#{time}]"
    end
  end
end
