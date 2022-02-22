# frozen_string_literal: true

module Asciidoctor
  module Prawn
    module Images
      class << self
        def extended base
          base.class.__send__ :alias_method, :_initial_image, :image
        end
      end

      # Dispatch to suitable image method in Prawn based on file extension.
      def image file, opts = {}
        # FIXME: handle case when SVG is an IO object
        if ::String === file
          if ((opts = opts.dup).delete :format) == 'svg' || (file.downcase.end_with? '.svg')
            #opts[:enable_file_requests_with_root] = (::File.dirname file) unless opts.key? :enable_file_requests_with_root
            #opts[:enable_web_requests] = allow_uri_read if !(opts.key? :enable_web_requests) && (respond_to? :allow_uri_read)
            #opts[:cache_images] = cache_uri if !(opts.key? :cache_images) && (respond_to? :cache_uri)
            #opts[:fallback_font_name] = fallback_svg_font_name if !(opts.key? :fallback_font_name) && (respond_to? :fallback_svg_font_name)
            if (opts.key? :fit) && (fit = opts.delete :fit) && !opts[:width] && !opts[:height]
              svg (::File.read file, mode: 'r:UTF-8'), opts do |svg_doc|
                max_width, max_height = fit
                svg_doc.calculate_sizing requested_width: max_width if max_width && svg_doc.sizing.output_width != max_width
                svg_doc.calculate_sizing requested_height: max_height if max_height && svg_doc.sizing.output_height > max_height
              end
            else
              svg (::File.read file, mode: 'r:UTF-8'), opts
            end
          else
            ::File.open(file, 'rb') {|fd| _initial_image fd, opts }
          end
        else
          _initial_image file, opts
        end
      end

      # Retrieve the intrinsic image dimensions for the specified path.
      #
      # Returns a Hash containing :width and :height keys that map to the image's
      # intrinsic width and height values (in pixels)
      def intrinsic_image_dimensions path, format
        if format == 'svg'
          img_obj = ::Prawn::SVG::Interface.new (::File.read path, mode: 'r:UTF-8'), self, {}
          img_size = img_obj.document.sizing
          { width: img_size.output_width, height: img_size.output_height }
        else
          # NOTE build_image_object caches image data previously loaded
          _, img_size = ::File.open(path, 'rb') {|fd| build_image_object fd }
          { width: img_size.width, height: img_size.height }
        end
      rescue
      end
    end

    ::Prawn::Document.extensions << Images
  end
end
