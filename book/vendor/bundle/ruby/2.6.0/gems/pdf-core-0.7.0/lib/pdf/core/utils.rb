module PDF
  module Core
    module Utils
      # rubocop: disable Security/MarshalLoad
      def deep_clone(object)
        Marshal.load(Marshal.dump(object))
      end
      # rubocop: enable Security/MarshalLoad
      module_function :deep_clone
    end
  end
end
