module PDF
  module Core
    class DocumentState #:nodoc:
      alias __initialize initialize
      def initialize(options)
        normalize_metadata(options)

        if options[:template]
          @store =
            if options[:print_scaling]
              PDF::Core::ObjectStore.new(
                template: options[:template],
                print_scaling: options[:print_scaling]
              )
            else
              PDF::Core::ObjectStore.new(template: options[:template])
            end
          @store.info.data.merge!(options[:info]) if options[:info]
        else
          @store =
            if options[:print_scaling]
              PDF::Core::ObjectStore.new(
                info: options[:info],
                print_scaling: options[:print_scaling]
              )
            else
              PDF::Core::ObjectStore.new(info: options[:info])
            end
        end

        @version = 1.3
        @pages = []
        @page = nil
        @trailer = options.fetch(:trailer, {})
        @compress = options.fetch(:compress, false)
        @encrypt = options.fetch(:encrypt, false)
        @encryption_key = options[:encryption_key]
        @skip_encoding = options.fetch(:skip_encoding, false)
        @before_render_callbacks = []
        @on_page_create_callback = nil
      end
    end
  end
end
