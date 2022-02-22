# frozen_string_literal: true

module Asciidoctor
  module PDF
    module FormattedText
      module SourceWrap
        NoBreakSpace = ?\u00a0

        def wrap array
          initialize_wrap array
          stop = nil
          highlight_line = nil
          unconsumed = @arranger.unconsumed
          if (linenum_fragment = unconsumed[0] || {})[:linenum]
            linenum_spacer = { text: NoBreakSpace + (' ' * (linenum_fragment[:text].length - 1)) }
          end
          until stop
            if linenum_spacer && (first_fragment = unconsumed[0])
              if first_fragment[:linenum]
                highlight_line = (second_fragment = unconsumed[1]) && (second_fragment[:highlight]) ? second_fragment.dup : nil
              else
                first_fragment[:text] = first_fragment[:text].lstrip
                @arranger.unconsumed.unshift highlight_line if highlight_line
                @arranger.unconsumed.unshift linenum_spacer.dup
              end
            end
            @line_wrap.wrap_line document: @document, kerning: @kerning, width: available_width, arranger: @arranger, disable_wrap_by_char: @disable_wrap_by_char
            if enough_height_for_this_line?
              move_baseline_down
              print_line
            else
              stop = true
            end
            stop ||= @single_line || @arranger.finished?
          end
          @text = @printed_lines.join ?\n
          @everything_printed = @arranger.finished?
          @arranger.unconsumed
        end
      end
    end
  end
end
