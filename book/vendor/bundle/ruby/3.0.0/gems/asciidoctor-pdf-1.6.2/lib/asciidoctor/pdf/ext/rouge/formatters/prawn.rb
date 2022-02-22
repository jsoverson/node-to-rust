# frozen_string_literal: true

module Rouge
  module Formatters
    # Transforms a token stream into an array of
    # formatted text fragments for use with Prawn.
    class Prawn < Formatter
      tag 'prawn'

      Tokens = ::Rouge::Token::Tokens
      LineOrientedTokens = [
        ::Rouge::Token::Tokens::Generic::Inserted,
        ::Rouge::Token::Tokens::Generic::Deleted,
        ::Rouge::Token::Tokens::Generic::Heading,
        ::Rouge::Token::Tokens::Generic::Subheading,
      ]

      LF = ?\n
      DummyText = ?\u0000
      NoBreakSpace = ?\u00a0
      InnerIndent = %(#{LF} )
      GuardedIndent = NoBreakSpace
      GuardedInnerIndent = %(#{LF}#{NoBreakSpace})
      BoldStyle = [:bold].to_set
      ItalicStyle = [:italic].to_set
      BoldItalicStyle = [:bold, :italic].to_set
      UnderlineStyle = [:underline].to_set

      def initialize opts = {}
        unless ::Rouge::Theme === (theme = opts[:theme])
          unless theme && (theme = ::Rouge::Theme.find theme)
            theme = ::Rouge::Themes::AsciidoctorPDFDefault
          end
          theme = theme.new
        end
        @theme = theme
        @normalized_colors = {}
        @background_colorizer = BackgroundColorizer.new line_gap: opts[:line_gap]
        @linenum_fragment_base = create_fragment Tokens::Generic::Lineno
        @highlight_line_fragment = create_highlight_line_fragment opts[:highlight_background_color]
      end

      def background_color
        @background_color ||= (normalize_color (@theme.style_for Tokens::Text).bg)
      end

      # Override format method so fragments don't get flatted to a string
      # and to add an options Hash.
      def format tokens, opts = {}
        stream tokens, opts
      end

      def stream tokens, opts = {}
        line_numbers = opts[:line_numbers]
        highlight_lines = opts[:highlight_lines]
        if line_numbers || highlight_lines
          linenum = (linenum = opts[:start_line] || 1) > 0 ? linenum : 1
          fragments = []
          line_numbers ? (fragments << (create_linenum_fragment linenum)) : (start_of_line = true)
          fragments << @highlight_line_fragment.dup if highlight_lines && highlight_lines[linenum]
          tokens.each do |tok, val|
            if val == LF
              fragments << { text: LF }
              linenum += 1
              line_numbers ? (fragments << (create_linenum_fragment linenum)) : (start_of_line = true)
              fragments << @highlight_line_fragment.dup if highlight_lines && highlight_lines[linenum]
            elsif val.include? LF
              # NOTE we assume if the fragment ends in a line feed, the intention was to match a line-oriented form
              line_oriented = val.end_with? LF
              base_fragment = create_fragment tok, val
              val.each_line do |line|
                if start_of_line
                  line[0] = GuardedIndent if line.start_with? ' '
                  start_of_line = nil
                end
                fragments << (line_oriented ? (base_fragment.merge text: line, inline_block: true) : (base_fragment.merge text: line))
                next unless line.end_with? LF
                # NOTE eagerly append linenum fragment or line highlight if there's a next line
                linenum += 1
                line_numbers ? (fragments << (create_linenum_fragment linenum)) : (start_of_line = true)
                fragments << @highlight_line_fragment.dup if highlight_lines && highlight_lines[linenum]
              end
            else
              if start_of_line
                val[0] = GuardedIndent if val.start_with? ' '
                start_of_line = nil
              end
              fragments << (create_fragment tok, val)
            end
          end
          # NOTE pad numbers that have less digits than the largest line number
          # FIXME we could store these fragments so we don't have find them again
          if line_numbers && (linenum_w = linenum.to_s.length) > 1
            # NOTE extra column is the trailing space after the line number
            linenum_w += 1
            fragments.each do |fragment|
              fragment[:text] = (fragment[:text].rjust linenum_w, NoBreakSpace).to_s if fragment[:linenum]
            end
          end
          fragments
        else
          start_of_line = true
          tokens.map do |tok, val|
            # match one or more consecutive endlines
            if val == LF || (val == (LF * val.length))
              start_of_line = true
              { text: val }
            else
              val[0] = GuardedIndent if start_of_line && (val.start_with? ' ')
              val.gsub! InnerIndent, GuardedInnerIndent if val.include? InnerIndent
              # QUESTION do we need the call to create_fragment if val contains only spaces? consider bg
              #fragment = create_fragment tok, val
              fragment = val.rstrip.empty? ? { text: val } : (create_fragment tok, val)
              # NOTE we assume if the fragment ends in a line feed, the intention was to match a line-oriented form
              fragment[:inline_block] = true if (start_of_line = val.end_with? LF)
              fragment
            end
          end
        end
      end

      # TODO: method could still be optimized (for instance, check if val is LF or empty)
      def create_fragment tok, val = nil
        fragment = val ? { text: val } : {}
        if (style_rules = @theme.style_for tok)
          if (bg = normalize_color style_rules.bg) && bg != background_color
            fragment[:background_color] = bg
            fragment[:callback] = @background_colorizer
            if LineOrientedTokens.include? tok
              fragment[:inline_block] = true unless style_rules[:inline_block] == false
              fragment[:extend] = true unless style_rules[:extend] == false
            else
              fragment[:inline_block] = true if style_rules[:inline_block]
              fragment[:extend] = true if style_rules[:extend]
            end
          end
          if (fg = normalize_color style_rules.fg)
            fragment[:color] = fg
          end
          if style_rules[:bold]
            fragment[:styles] = style_rules[:italic] ? BoldItalicStyle.dup : BoldStyle.dup
          elsif style_rules[:italic]
            fragment[:styles] = ItalicStyle.dup
          end
          if style_rules[:underline]
            if fragment.key? :styles
              fragment[:styles] << UnderlineStyle[0]
            else
              fragment[:styles] = UnderlineStyle.dup
            end
          end
        end
        fragment
      end

      def create_linenum_fragment linenum
        @linenum_fragment_base.merge text: %(#{linenum} ), linenum: linenum
      end

      def create_highlight_line_fragment bg_color
        {
          background_color: (bg_color || 'FFFFCC'),
          callback: @background_colorizer,
          extend: true,
          highlight: true,
          inline_block: true,
          text: DummyText,
          width: 0,
        }
      end

      def normalize_color raw
        return unless raw
        if (normalized = @normalized_colors[raw])
          normalized
        else
          normalized = (raw.start_with? '#') ? (raw.slice 1, raw.length) : raw
          normalized = normalized.each_char.map {|c| c * 2 }.join if normalized.length == 3
          @normalized_colors[raw] = normalized
        end
      end

      class BackgroundColorizer
        def initialize opts = {}
          @line_gap = opts[:line_gap] || 0
        end

        def render_behind fragment
          pdf = fragment.document
          data = fragment.format_state
          prev_fill_color = pdf.fill_color
          pdf.fill_color data[:background_color]
          if data[:inline_block]
            fragment_width = data[:extend] ? pdf.bounds.width - fragment.left : fragment.width
            v_gap = @line_gap
          else
            fragment_width = fragment.width
            v_gap = 0
          end
          pdf.fill_rectangle [fragment.left, fragment.top + v_gap * 0.5], fragment_width, (fragment.height + v_gap)
          pdf.fill_color prev_fill_color
          fragment.conceal if fragment.text == DummyText
          nil
        end
      end
    end
  end
end
