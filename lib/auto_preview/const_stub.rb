# frozen_string_literal: true

module AutoPreview
  module CompiledTemplates
    # Recursive stub class that handles any depth of constant nesting
    # Used to auto-mock undefined constants like Primer::Beta::Button
    def self.create_const_stub(parent_name = nil)
      stub = Class.new do
        @parent_name = parent_name
        
        class << self
          attr_accessor :parent_name
          
          def full_name
            if parent_name
              "#{parent_name}::#{name&.split('::')&.last}"
            else
              name
            end
          end
          
          def method_missing(method_name, *args, **kwargs, &block)
            AutoPreview::MockContext::MockValue.new("#{full_name}.#{method_name}")
          end
          
          def respond_to_missing?(method_name, include_private = false)
            true
          end
          
          def const_missing(child_name)
            child_stub = AutoPreview::CompiledTemplates.create_const_stub(full_name)
            const_set(child_name, child_stub)
            child_stub
          end
          
          def new(*args, **kwargs, &block)
            AutoPreview::MockContext::MockValue.new(full_name || "anonymous")
          end
        end
      end
      stub.parent_name = parent_name
      stub
    end
  end
end
