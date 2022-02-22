module Prawn
  class Document
    module Internals
      delegate [:open_graphics_state] => :renderer

      # wraps existing content streams with two new streams
      # containing just 'q' and 'Q'. This ensures that prawn
      # has a pristine graphics context before it starts adding content.
      #
      # adds a new, empty content stream to each page. Used in templating so
      # that imported content streams can be left pristine
      #
      def fresh_content_streams(options = {})
        (1..page_count).each do |i|
          go_to_page i

          state.page.wrap_graphics_state
          state.page.new_content_stream
          apply_margin_options(options)
          generate_margin_box
          use_graphic_settings(options[:template])
          forget_text_rendering_mode!
        end
      end
    end
  end
end
