module PDF
  module Core
    class Page #:nodoc:
      alias __initialize initialize
      def initialize(document, options = {})
        @document = document
        @margins = options[:margins] || {
          left: 36,
          right: 36,
          top: 36,
          bottom: 36
        }
        @crops = options[:crops] || ZERO_INDENTS
        @bleeds = options[:bleeds] || ZERO_INDENTS
        @trims = options[:trims] || ZERO_INDENTS
        @art_indents = options[:art_indents] || ZERO_INDENTS
        @stack = GraphicStateStack.new(options[:graphic_state])
        if options[:object_id]
          init_from_object(options)
        else
          init_new_page(options)
        end
      end

      # Prepend a content stream containing 'q',
      # and append a content stream containing 'Q'.
      # This ensures that prawn has a pristine graphics state
      # before it starts adding content.
      def wrap_graphics_state
        dictionary.data[:Contents] = Array(dictionary.data[:Contents])

        # Save graphics context
        @content = document.ref({})
        dictionary.data[:Contents].unshift(document.state.store[@content])
        document.add_content 'q'

        # Restore graphics context
        @content = document.ref({})
        dictionary.data[:Contents] << document.state.store[@content]
        document.add_content 'Q'
      end

      # As per the PDF spec, each page can have multiple content streams. This
      # will add a fresh, empty content stream this the page, mainly for use in
      # loading template files.
      #
      def new_content_stream
        return if in_stamp_stream?

        dictionary.data[:Contents] = Array(dictionary.data[:Contents])
        @content = document.ref({})
        dictionary.data[:Contents] << document.state.store[@content]
        document.open_graphics_state
      end

      unless method_defined? :imported_page?
        def imported_page?
          @imported_page
        end
      end

      alias __dimensions dimensions if method_defined? :dimensions
      def dimensions
        if imported_page?
          media_box = inherited_dictionary_value(:MediaBox)
          return media_box.data if media_box.is_a?(PDF::Core::Reference)
          return media_box
        end

        coords = PDF::Core::PageGeometry::SIZES[size] || size
        [0, 0] +
          case layout
          when :portrait
            coords
          when :landscape
            coords.reverse
          else
            raise PDF::Core::Errors::InvalidPageLayout,
              'Layout must be either :portrait or :landscape'
          end
      end

      if method_defined? :init_from_object
        alias __init_from_object init_from_object
      end
      def init_from_object(options)
        @dictionary = options[:object_id].to_i
        if options[:page_template]
          dictionary.data[:Parent] = document.state.store.pages
        end

        unless dictionary.data[:Contents].is_a?(Array) # content only on leafs
          @content = dictionary.data[:Contents].identifier
        end

        @stamp_stream = nil
        @stamp_dictionary = nil
        @imported_page = true
      end

      alias __init_new_page init_new_page if method_defined? :init_new_page
      def init_new_page(options)
        @size = options[:size] || 'LETTER'
        @layout = options[:layout] || :portrait

        @stamp_stream = nil
        @stamp_dictionary = nil
        @imported_page = false

        @content = document.ref({})
        content << 'q' << "\n"
        @dictionary = document.ref(
          Type: :Page,
          Parent: document.state.store.pages,
          MediaBox: dimensions,
          CropBox: crop_box,
          BleedBox: bleed_box,
          TrimBox: trim_box,
          ArtBox: art_box,
          Contents: content
        )

        resources[:ProcSet] = %i[PDF Text ImageB ImageC ImageI]
      end
    end
  end
end
