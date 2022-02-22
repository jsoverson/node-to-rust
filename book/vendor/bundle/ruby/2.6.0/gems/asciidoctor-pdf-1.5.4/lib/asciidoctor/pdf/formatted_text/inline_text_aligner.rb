# frozen_string_literal: true

module Asciidoctor::PDF::FormattedText
  module InlineTextAligner
    module_function

    def render_behind fragment
      document = fragment.document
      text = fragment.text
      x = fragment.left
      y = fragment.baseline
      align = fragment.format_state[:align]
      if align == :center || align == :right
        if (gap_width = fragment.width - (document.width_of text)) != 0
          x += gap_width * (align == :center ? 0.5 : 1)
        end
      end
      document.draw_text! text, at: [x, y]
      fragment.conceal
    end
  end
end
