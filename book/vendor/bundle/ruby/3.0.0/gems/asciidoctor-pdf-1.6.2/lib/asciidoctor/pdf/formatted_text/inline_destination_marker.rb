# frozen_string_literal: true

module Asciidoctor::PDF::FormattedText
  module InlineDestinationMarker
    module_function

    # render_behind is called before the text is printed
    def render_behind fragment
      unless (pdf = fragment.document).scratch?
        if (name = fragment.format_state[:name])
          (pdf.instance_variable_get :@index).link_dest_to_page name, pdf.page_number if fragment.format_state[:type] == :indexterm
          # get precise position of the reference (x, y)
          dest_rect = fragment.absolute_bounding_box
          pdf.add_dest name, (pdf.dest_xyz dest_rect[0], dest_rect[-1])
          # prevent any text from being written
          fragment.conceal
        end
      end
    end
  end
end
