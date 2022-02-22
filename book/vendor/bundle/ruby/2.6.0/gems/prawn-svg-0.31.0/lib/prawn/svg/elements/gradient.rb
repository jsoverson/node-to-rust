class Prawn::SVG::Elements::Gradient < Prawn::SVG::Elements::Base
  attr_reader :parent_gradient
  attr_reader :x1, :y1, :x2, :y2, :cx, :cy, :fx, :fy, :radius, :units, :stops, :transform_matrix

  TAG_NAME_TO_TYPE = {
    "linearGradient" => :linear,
    "radialGradient" => :radial
  }

  def parse
    # A gradient tag without an ID is inaccessible and can never be used
    raise SkipElementQuietly if attributes['id'].nil?

    @parent_gradient = document.gradients[href_attribute[1..-1]] if href_attribute && href_attribute[0] == '#'

    assert_compatible_prawn_version
    load_gradient_configuration
    load_coordinates
    load_stops

    document.gradients[attributes['id']] = self

    raise SkipElementQuietly # we don't want anything pushed onto the call stack
  end

  def gradient_arguments(element)
    # Passing in a transformation matrix to the apply_transformations option is supported
    # by a monkey patch installed by prawn-svg.  Prawn only sees this as a truthy variable.
    #
    # See Prawn::SVG::Extensions::AdditionalGradientTransforms for details.
    base_arguments = {stops: stops, apply_transformations: transform_matrix || true}

    arguments = specific_gradient_arguments(element)
    arguments.merge(base_arguments) if arguments
  end

  private

  def specific_gradient_arguments(element)
    if units == :bounding_box
      bounding_x1, bounding_y1, bounding_x2, bounding_y2 = element.bounding_box
      return if bounding_y2.nil?

      width = bounding_x2 - bounding_x1
      height = bounding_y1 - bounding_y2
    end

    case [type, units]
    when [:linear, :bounding_box]
      from = [bounding_x1 + width * x1, bounding_y1 - height * y1]
      to   = [bounding_x1 + width * x2, bounding_y1 - height * y2]

      {from: from, to: to}

    when [:linear, :user_space]
      {from: [x1, y1], to: [x2, y2]}

    when [:radial, :bounding_box]
      center = [bounding_x1 + width * cx, bounding_y1 - height * cy]
      focus  = [bounding_x1 + width * fx, bounding_y1 - height * fy]

      # Note: Chrome, at least, implements radial bounding box radiuses as
      # having separate X and Y components, so in bounding box mode their
      # gradients come out as ovals instead of circles.  PDF radial shading
      # doesn't have the option to do this, and it's confusing why the
      # Chrome user space gradients don't apply the same logic anyway.
      hypot = Math.sqrt(width * width + height * height)
      {from: focus, r1: 0, to: center, r2: radius * hypot}

    when [:radial, :user_space]
      {from: [fx, fy], r1: 0, to: [cx, cy], r2: radius}

    else
      raise "unexpected type/unit system"
    end
  end

  def type
    TAG_NAME_TO_TYPE.fetch(name)
  end

  def assert_compatible_prawn_version
    if (Prawn::VERSION.split(".").map(&:to_i) <=> [2, 2, 0]) == -1
      raise SkipElementError, "Prawn 2.2.0+ must be used if you'd like prawn-svg to render gradients"
    end
  end

  def load_gradient_configuration
    @units = attributes["gradientUnits"] == 'userSpaceOnUse' ? :user_space : :bounding_box

    if transform = attributes["gradientTransform"]
      @transform_matrix = parse_transform_attribute(transform)
    end

    if (spread_method = attributes['spreadMethod']) && spread_method != "pad"
      warnings << "prawn-svg only currently supports the 'pad' spreadMethod attribute value"
    end
  end

  def load_coordinates
    case [type, units]
    when [:linear, :bounding_box]
      @x1 = parse_zero_to_one(attributes["x1"], 0)
      @y1 = parse_zero_to_one(attributes["y1"], 0)
      @x2 = parse_zero_to_one(attributes["x2"], 1)
      @y2 = parse_zero_to_one(attributes["y2"], 0)

    when [:linear, :user_space]
      @x1 = x(attributes["x1"])
      @y1 = y(attributes["y1"])
      @x2 = x(attributes["x2"])
      @y2 = y(attributes["y2"])

    when [:radial, :bounding_box]
      @cx = parse_zero_to_one(attributes["cx"], 0.5)
      @cy = parse_zero_to_one(attributes["cy"], 0.5)
      @fx = parse_zero_to_one(attributes["fx"], cx)
      @fy = parse_zero_to_one(attributes["fy"], cy)
      @radius = parse_zero_to_one(attributes["r"], 0.5)

    when [:radial, :user_space]
      @cx = x(attributes["cx"] || '50%')
      @cy = y(attributes["cy"] || '50%')
      @fx = x(attributes["fx"] || attributes["cx"])
      @fy = y(attributes["fy"] || attributes["cy"])
      @radius = pixels(attributes["r"] || '50%')

    else
      raise "unexpected type/unit system"
    end
  end

  def load_stops
    stop_elements = source.elements.map do |child|
      element = Prawn::SVG::Elements::Base.new(document, child, [], Prawn::SVG::State.new)
      element.process
      element
    end.select do |element|
      element.name == 'stop' && element.attributes["offset"]
    end

    @stops = stop_elements.each.with_object([]) do |child, result|
      offset = parse_zero_to_one(child.attributes["offset"])

      # Offsets must be strictly increasing (SVG 13.2.4)
      if result.last && result.last.first > offset
        offset = result.last.first
      end

      if color_hex = Prawn::SVG::Color.color_to_hex(child.properties.stop_color)
        result << [offset, color_hex]
      end
    end

    if stops.empty?
      if parent_gradient.nil? || parent_gradient.stops.empty?
        raise SkipElementError, "gradient does not have any valid stops"
      end

      @stops = parent_gradient.stops
    else
      stops.unshift([0, stops.first.last]) if stops.first.first > 0
      stops.push([1, stops.last.last])     if stops.last.first  < 1
    end
  end

  def parse_zero_to_one(string, default = 0)
    string = string.to_s.strip
    return default if string == ""

    value = string.to_f
    value /= 100.0 if string[-1..-1] == '%'
    [0.0, value, 1.0].sort[1]
  end
end
