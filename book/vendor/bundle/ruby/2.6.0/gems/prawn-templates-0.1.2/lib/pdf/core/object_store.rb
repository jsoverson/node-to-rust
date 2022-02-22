module PDF
  module Core
    class ObjectStore #:nodoc:
      alias __initialize initialize
      def initialize(opts = {})
        @objects = {}
        @identifiers = []

        load_file(opts[:template]) if opts[:template]

        @info ||= ref(opts[:info] || {}).identifier
        @root ||= ref(Type: :Catalog).identifier
        if opts[:print_scaling] == :none
          root.data[:ViewerPreferences] = { PrintScaling: :None }
        end
        if pages.nil?
          root.data[:Pages] = ref(Type: :Pages, Count: 0, Kids: [])
        end
      end

      alias __utf8? utf8? if method_defined? :utf8?
      def utf8?(str)
        str.force_encoding(::Encoding::UTF_8)
        str.valid_encoding?
      end
    end
  end
end
