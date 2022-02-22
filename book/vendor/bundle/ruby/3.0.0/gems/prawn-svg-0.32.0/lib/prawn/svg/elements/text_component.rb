class Prawn::SVG::Elements::TextComponent < Prawn::SVG::Elements::DepthFirstBase
  attr_reader :commands

  Printable = Struct.new(:element, :text, :leading_space?, :trailing_space?)
  TextState = Struct.new(:parent, :x, :y, :dx, :dy, :rotation, :spacing, :mode, :text_length, :length_adjust)

  def parse
    if state.inside_clip_path
      raise SkipElementError, "<text> elements are not supported in clip paths"
    end

    state.text.x = (attributes['x'] || "").split(COMMA_WSP_REGEXP).collect { |n| x(n) }
    state.text.y = (attributes['y'] || "").split(COMMA_WSP_REGEXP).collect { |n| y(n) }
    state.text.dx = (attributes['dx'] || "").split(COMMA_WSP_REGEXP).collect { |n| x_pixels(n) }
    state.text.dy = (attributes['dy'] || "").split(COMMA_WSP_REGEXP).collect { |n| y_pixels(n) }
    state.text.rotation = (attributes['rotate'] || "").split(COMMA_WSP_REGEXP).collect(&:to_f)
    state.text.text_length = normalize_length(attributes['textLength'])
    state.text.length_adjust = attributes['lengthAdjust']
    state.text.spacing = calculate_character_spacing
    state.text.mode = calculate_text_rendering_mode

    @commands = []

    svg_text_children.each do |child|
      if child.node_type == :text
        append_text(child)
      else
        case child.name
        when 'tspan', 'tref'
          append_child(child)
        else
          warnings << "Unknown tag '#{child.name}' inside text tag; ignoring"
        end
      end
    end
  end

  def apply
    raise SkipElementQuietly if computed_properties.display == "none"

    font = select_font
    apply_font(font) if font

    # text_anchor isn't a Prawn option; we have to do some math to support it
    # and so we handle this in Prawn::SVG::Interface#rewrite_call_arguments
    opts = {
      size:        computed_properties.numerical_font_size,
      style:       font && font.subfamily,
      text_anchor: computed_properties.text_anchor,
    }

    opts[:decoration] = computed_properties.text_decoration unless computed_properties.text_decoration == 'none'

    if state.text.parent
      add_call_and_enter 'character_spacing', state.text.spacing unless state.text.spacing == state.text.parent.spacing
      add_call_and_enter 'text_rendering_mode', state.text.mode unless state.text.mode == state.text.parent.mode
    else
      add_call_and_enter 'character_spacing', state.text.spacing unless state.text.spacing == 0
      add_call_and_enter 'text_rendering_mode', state.text.mode unless state.text.mode == :fill
    end

    @commands.each do |command|
      case command
      when Printable
        apply_text(command.text, opts)
      when self.class
        add_call 'save'
        command.apply_step(calls)
        add_call 'restore'
      else
        raise
      end
    end

    # It's possible there was no text to render.  In that case, add a 'noop' so character_spacing/text_rendering_mode
    # don't blow up when they find they don't have a block to execute.
    add_call 'noop' if calls.empty?
  end

  protected

  def append_text(child)
    if state.preserve_space
      text = child.value.tr("\n\t", ' ')
    else
      text = child.value.tr("\n", '').tr("\t", ' ')
      leading = text[0] == ' '
      trailing = text[-1] == ' '
      text = text.strip.gsub(/ {2,}/, ' ')
    end

    @commands << Printable.new(self, text, leading, trailing)
  end

  def append_child(child)
    new_state = state.dup
    new_state.text = TextState.new(state.text)

    element = self.class.new(document, child, calls, new_state)
    @commands << element
    element.parse_step
  end

  def apply_text(text, opts)
    while text != ""
      x = y = dx = dy = rotate = nil
      remaining = rotation_remaining = false

      list = state.text
      while list
        shifted = list.x.shift
        x ||= shifted
        shifted = list.y.shift
        y ||= shifted
        shifted = list.dx.shift
        dx ||= shifted
        shifted = list.dy.shift
        dy ||= shifted

        shifted = list.rotation.length > 1 ? list.rotation.shift : list.rotation.first
        if shifted && rotate.nil?
          rotate = shifted
          remaining ||= list.rotation != [0]
        end

        remaining ||= list.x.any? || list.y.any? || list.dx.any? || list.dy.any? || (rotate && rotate != 0)
        rotation_remaining ||= list.rotation.length > 1
        list = list.parent
      end

      opts[:at] = [x || :relative, y || :relative]
      opts[:offset] = [dx || 0, dy || 0]

      if rotate && rotate != 0
        opts[:rotate] = -rotate
      else
        opts.delete(:rotate)
      end

      if state.text.text_length
        if state.text.length_adjust == 'spacingAndGlyphs'
          opts[:stretch_to_width] = state.text.text_length
        else
          opts[:pad_to_width] = state.text.text_length
        end
      end

      if remaining
        add_call 'draw_text', text[0..0], **opts.dup
        text = text[1..-1]
      else
        add_call 'draw_text', text, **opts.dup

        # we can get to this path with rotations still pending
        # solve this by shifting them out by the number of
        # characters we've just drawn
        shift = text.length - 1
        if rotation_remaining && shift > 0
          list = state.text
          while list
            count = [shift, list.rotation.length - 1].min
            list.rotation.shift(count) if count > 0
            list = list.parent
          end
        end

        break
      end
    end
  end

  def svg_text_children
    text_children.select do |child|
      child.node_type == :text || child.namespace == SVG_NAMESPACE || child.namespace == ''
    end
  end

  def text_children
    if name == 'tref'
      reference = find_referenced_element
      reference ? reference.source.children : []
    else
      source.children
    end
  end

  def find_referenced_element
    href = href_attribute

    if href && href[0..0] == '#'
      element = document.elements_by_id[href[1..-1]]
      element if element.name == 'text'
    end
  end

  def select_font
    font_families = [computed_properties.font_family, document.fallback_font_name]
    font_style = :italic if computed_properties.font_style == 'italic'
    font_weight = Prawn::SVG::Font.weight_for_css_font_weight(computed_properties.font_weight)

    font_families.compact.each do |name|
      font = document.font_registry.load(name, font_weight, font_style)
      return font if font
    end

    warnings << "Font family '#{computed_properties.font_family}' style '#{computed_properties.font_style}' is not a known font, and the fallback font could not be found."
    nil
  end

  def apply_font(font)
    add_call 'font', font.name, style: font.subfamily
  end

  def calculate_text_rendering_mode
    fill = computed_properties.fill != 'none'
    stroke = computed_properties.stroke != 'none'

    if fill && stroke
      :fill_stroke
    elsif fill
      :fill
    elsif stroke
      :stroke
    else
      :invisible
    end
  end

  def calculate_character_spacing
    spacing = computed_properties.letter_spacing
    spacing == 'normal' ? 0 : pixels(spacing)
  end

  # overridden, we don't want to call fill/stroke as draw_text does this for us
  def apply_drawing_call
  end

  def normalize_length(length)
    x_pixels(length) if length && length.match(/\d/)
  end
end
