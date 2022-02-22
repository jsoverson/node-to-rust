#
# Prawn::SVG::Interface makes a Prawn::SVG::Document instance, uses that object to parse the supplied
# SVG into Prawn-compatible method calls, and then calls the Prawn methods.
#
module Prawn
  module SVG
    class Interface
      VALID_OPTIONS = [:at, :position, :vposition, :width, :height, :cache_images, :enable_web_requests, :enable_file_requests_with_root, :fallback_font_name]

      attr_reader :data, :prawn, :document, :options

      #
      # Creates a Prawn::SVG object.
      #
      # +data+ is the SVG data to convert.  +prawn+ is your Prawn::Document object.
      #
      # See README.md for the options that can be passed to this method.
      #
      def initialize(data, prawn, options, &block)
        Prawn.verify_options VALID_OPTIONS, options

        @data = data
        @prawn = prawn
        @options = options

        font_registry = Prawn::SVG::FontRegistry.new(prawn.font_families)

        @document = Document.new(data, [prawn.bounds.width, prawn.bounds.height], options, font_registry: font_registry, &block)
      end

      #
      # Draws the SVG to the Prawn::Document object.
      #
      def draw
        if @document.sizing.invalid?
          @document.warnings << "Zero or negative sizing data means this SVG cannot be rendered"
          return
        end

        @document.warnings.clear

        prawn.save_font do
          prawn.bounding_box(position, :width => @document.sizing.output_width, :height => @document.sizing.output_height) do
            prawn.save_graphics_state do
              clip_rectangle 0, 0, @document.sizing.output_width, @document.sizing.output_height

              calls = []
              root_element = Prawn::SVG::Elements::Root.new(@document, @document.root, calls)
              root_element.process

              proc_creator(prawn, calls).call
            end
          end
        end
      end

      def sizing
        document.sizing
      end

      def resize(width: nil, height: nil)
        document.calculate_sizing(requested_width: width, requested_height: height)
      end

      def position
        @options[:at] || [x_based_on_requested_alignment, y_based_on_requested_alignment]
      end

      def self.font_path # backwards support for when the font_path used to be stored on this class
        Prawn::SVG::FontRegistry.font_path
      end

      private

      def x_based_on_requested_alignment
        case options[:position]
        when :left, nil
          0
        when :center, :centre
          (@document.sizing.bounds[0] - @document.sizing.output_width) / 2.0
        when :right
          @document.sizing.bounds[0] - @document.sizing.output_width
        when Numeric
          options[:position]
        else
          raise ArgumentError, "options[:position] must be one of nil, :left, :right, :center or a number"
        end
      end

      def y_based_on_requested_alignment
        case options[:vposition]
        when nil
          prawn.cursor
        when :top
          @document.sizing.bounds[1]
        when :center, :centre
          @document.sizing.bounds[1] - (@document.sizing.bounds[1] - @document.sizing.output_height) / 2.0
        when :bottom
          @document.sizing.output_height
        when Numeric
          @document.sizing.bounds[1] - options[:vposition]
        else
          raise ArgumentError, "options[:vposition] must be one of nil, :top, :right, :bottom or a number"
        end
      end

      def proc_creator(prawn, calls)
        Proc.new {issue_prawn_command(prawn, calls)}
      end

      def issue_prawn_command(prawn, calls)
        calls.each do |call, arguments, kwarguments, children|
          skip = false

          rewrite_call_arguments(prawn, call, arguments, kwarguments) do
            issue_prawn_command(prawn, children) if children.any?
            skip = true
          end

          if skip
            # the call has been overridden
          elsif children.empty? && call != 'transparent' # some prawn calls complain if they aren't supplied a block
            if RUBY_VERSION >= '2.7' || !kwarguments.empty?
              prawn.send(call, *arguments, **kwarguments)
            else
              prawn.send(call, *arguments)
            end
          else
            if RUBY_VERSION >= '2.7' || !kwarguments.empty?
              prawn.send(call, *arguments, **kwarguments, &proc_creator(prawn, children))
            else
              prawn.send(call, *arguments, &proc_creator(prawn, children))
            end
          end
        end
      end

      def rewrite_call_arguments(prawn, call, arguments, kwarguments)
        case call
        when 'text_group'
          @cursor = [0, document.sizing.output_height]
          yield

        when 'draw_text'
          text, options = arguments.first, kwarguments

          at = options.fetch(:at)

          at[0] = @cursor[0] if at[0] == :relative
          at[1] = @cursor[1] if at[1] == :relative

          if offset = options.delete(:offset)
            at[0] += offset[0]
            at[1] -= offset[1]
          end

          width = prawn.width_of(text, options.merge(kerning: true))

          if stretch_to_width = options.delete(:stretch_to_width)
            factor = stretch_to_width.to_f * 100 / width.to_f
            prawn.add_content "#{factor} Tz"
            width = stretch_to_width.to_f
          end

          if pad_to_width = options.delete(:pad_to_width)
            padding_required = pad_to_width.to_f - width.to_f
            padding_per_character = padding_required / text.length.to_f
            prawn.add_content "#{padding_per_character} Tc"
            width = pad_to_width.to_f
          end

          case options.delete(:text_anchor)
          when 'middle'
            at[0] -= width / 2
            @cursor = [at[0] + width / 2, at[1]]
          when 'end'
            at[0] -= width
            @cursor = at.dup
          else
            @cursor = [at[0] + width, at[1]]
          end

          decoration = options.delete(:decoration)
          if decoration == 'underline'
            prawn.save_graphics_state do
              prawn.line_width 1
              prawn.line [at[0], at[1] - 1.25], [at[0] + width, at[1] - 1.25]
              prawn.stroke
            end
          end

        when 'transformation_matrix'
          left = prawn.bounds.absolute_left
          top = prawn.bounds.absolute_top
          arguments[4] += left - (left * arguments[0] + top * arguments[2])
          arguments[5] += top - (left * arguments[1] + top * arguments[3])

        when 'clip'
          prawn.add_content "W n" # clip to path
          yield

        when 'save'
          prawn.save_graphics_state
          yield

        when 'restore'
          prawn.restore_graphics_state
          yield

        when "end_path"
          yield
          prawn.add_content "n" # end path

        when 'fill_and_stroke'
          yield
          # prawn (as at 2.0.1 anyway) uses 'b' for its fill_and_stroke.  'b' is 'h' (closepath) + 'B', and we
          # never want closepath to be automatically run as it stuffs up many drawing operations, such as dashes
          # and line caps, and makes paths close that we didn't ask to be closed when fill is specified.
          even_odd = kwarguments[:fill_rule] == :even_odd
          content  = even_odd ? 'B*' : 'B'
          prawn.add_content content

        when 'noop'
          yield
        end
      end

      def clip_rectangle(x, y, width, height)
        prawn.move_to x, y
        prawn.line_to x + width, y
        prawn.line_to x + width, y + height
        prawn.line_to x, y + height
        prawn.close_path
        prawn.add_content "W n" # clip to path
      end
    end
  end
end
