module Prawn::SVG::TransformParser
  def parse_transform_attribute(transform)
    matrix = Matrix.identity(3)

    parse_css_method_calls(transform).each do |name, arguments|
      case name
      when 'translate'
        x, y = arguments
        matrix *= Matrix[[1, 0, x_pixels(x.to_f)], [0, 1, -y_pixels(y.to_f)], [0, 0, 1]]

      when 'translateX'
        x = arguments.first
        matrix *= Matrix[[1, 0, x_pixels(x.to_f)], [0, 1, 0], [0, 0, 1]]

      when 'translateY'
        y = arguments.first
        matrix *= Matrix[[1, 0, 0], [0, 1, -y_pixels(y.to_f)], [0, 0, 1]]

      when 'rotate'
        angle, x, y = arguments.collect { |a| a.to_f }
        angle = angle * Math::PI / 180.0

        case arguments.length
        when 1
          matrix *= Matrix[[Math.cos(angle), Math.sin(angle), 0], [-Math.sin(angle), Math.cos(angle), 0], [0, 0, 1]]
        when 3
          matrix *= Matrix[[1, 0, x_pixels(x.to_f)], [0, 1, -y_pixels(y.to_f)], [0, 0, 1]]
          matrix *= Matrix[[Math.cos(angle), Math.sin(angle), 0], [-Math.sin(angle), Math.cos(angle), 0], [0, 0, 1]]
          matrix *= Matrix[[1, 0, -x_pixels(x.to_f)], [0, 1, y_pixels(y.to_f)], [0, 0, 1]]
        else
          warnings << "transform 'rotate' must have either one or three arguments"
        end

      when 'scale'
        x_scale = arguments[0].to_f
        y_scale = (arguments[1] || x_scale).to_f
        matrix *= Matrix[[x_scale, 0, 0], [0, y_scale, 0], [0, 0, 1]]

      when 'skewX'
        angle = arguments[0].to_f * Math::PI / 180.0
        matrix *= Matrix[[1, -Math.tan(angle), 0], [0, 1, 0], [0, 0, 1]]

      when 'skewY'
        angle = arguments[0].to_f * Math::PI / 180.0
        matrix *= Matrix[[1, 0, 0], [-Math.tan(angle), 1, 0], [0, 0, 1]]

      when 'matrix'
        if arguments.length != 6
          warnings << "transform 'matrix' must have six arguments"
        else
          a, b, c, d, e, f = arguments.collect { |argument| argument.to_f }
          matrix *= Matrix[[a, -c, e], [-b, d, -f], [0, 0, 1]]
        end

      else
        warnings << "Unknown/unsupported transformation '#{name}'; ignoring"
      end
    end

    matrix.to_a[0..1].transpose.flatten
  end

  private

  def parse_css_method_calls(string)
    string.scan(/\s*(\w+)\(([^)]+)\)\s*/).collect do |call|
      name, argument_string = call
      arguments = argument_string.strip.split(/\s*[,\s]\s*/)
      [name, arguments]
    end
  end
end
