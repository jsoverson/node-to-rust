# frozen_string_literal: true

module Asciidoctor::PDF::FormattedText
  module InlineImageRenderer
    module_function

    # Embeds the image object in this fragment into the document in place of the
    # text that was previously used to reserve space for the image in the line.
    #
    # If the image height is less than 1.5x the height of the surrounding text,
    # it is centered vertically in the line. If the image height is greater, then
    # the image is aligned to the bottom of the text.
    #
    # Note that render_behind is called before the text is printed.
    #
    # This handler is only used on the main document (not the scratch document).
    #
    def render_behind fragment
      pdf = fragment.document
      data = fragment.format_state
      if data.key? :line_height_increased
        # align image to bottom of line (differs from fragment.top by descender value)
        image_top = fragment.bottom + data[:image_height]
      else
        # center image in line
        image_top = fragment.top - ((fragment.height - data[:image_height]) / 2.0)
      end
      image_left = fragment.left + ((fragment.width - data[:image_width]) / 2.0)
      case data[:image_format]
      when 'svg'
        (image_obj = data[:image_obj]).options[:at] = [image_left, image_top]
        # NOTE prawn-svg messes with the cursor; use float to workaround
        # NOTE prawn-svg 0.24.0, 0.25.0, & 0.25.1 didn't restore font after call to draw (see mogest/prawn-svg#80)
        pdf.float do
          pdf.character_spacing(data[:actual_character_spacing]) { image_obj.draw }
          image_obj.document.warnings.each do |img_warning|
            # NOTE shim logger can't be imported into a module, so use the one from the PDF document instead
            pdf.logger.warn %(problem encountered in image: #{data[:image_path]}; #{img_warning})
          end
        end
      else
        pdf.embed_image data[:image_obj], data[:image_info], at: [image_left, image_top], width: data[:image_width], height: data[:image_height]
      end
      # ...or use the public interface, loading the image again
      #pdf.image data[:image_path], at: [image_left, image_top], width: data[:image_width]

      # prevent any text from being written
      fragment.conceal
    end
  end
end
