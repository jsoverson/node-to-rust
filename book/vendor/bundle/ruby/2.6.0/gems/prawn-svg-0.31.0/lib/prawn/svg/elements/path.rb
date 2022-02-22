class Prawn::SVG::Elements::Path < Prawn::SVG::Elements::Base
  include Prawn::SVG::Calculators::ArcToBezierCurve
  include Prawn::SVG::Pathable

  INSIDE_SPACE_REGEXP = /[ \t\r\n,]*/
  OUTSIDE_SPACE_REGEXP = /[ \t\r\n]*/
  INSIDE_REGEXP = /#{INSIDE_SPACE_REGEXP}(?>([+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:(?<=[0-9])[eE][+-]?[0-9]+)?))/
  FLAG_REGEXP = /#{INSIDE_SPACE_REGEXP}([01])/
  COMMAND_REGEXP = /^#{OUTSIDE_SPACE_REGEXP}([A-Za-z])((?:#{INSIDE_REGEXP})*)#{OUTSIDE_SPACE_REGEXP}/

  A_PARAMETERS_REGEXP = /^#{INSIDE_REGEXP}#{INSIDE_REGEXP}#{INSIDE_REGEXP}#{FLAG_REGEXP}#{FLAG_REGEXP}#{INSIDE_REGEXP}#{INSIDE_REGEXP}/
  ONE_PARAMETER_REGEXP = /^#{INSIDE_REGEXP}/
  TWO_PARAMETER_REGEXP = /^#{INSIDE_REGEXP}#{INSIDE_REGEXP}/
  FOUR_PARAMETER_REGEXP = /^#{INSIDE_REGEXP}#{INSIDE_REGEXP}#{INSIDE_REGEXP}#{INSIDE_REGEXP}/
  SIX_PARAMETER_REGEXP = /^#{INSIDE_REGEXP}#{INSIDE_REGEXP}#{INSIDE_REGEXP}#{INSIDE_REGEXP}#{INSIDE_REGEXP}#{INSIDE_REGEXP}/

  COMMAND_MATCH_MAP = {
    'A' => A_PARAMETERS_REGEXP,
    'C' => SIX_PARAMETER_REGEXP,
    'H' => ONE_PARAMETER_REGEXP,
    'L' => TWO_PARAMETER_REGEXP,
    'M' => TWO_PARAMETER_REGEXP,
    'Q' => FOUR_PARAMETER_REGEXP,
    'S' => FOUR_PARAMETER_REGEXP,
    'T' => TWO_PARAMETER_REGEXP,
    'V' => ONE_PARAMETER_REGEXP,
    'Z' => //,
  }

  PARAMETERLESS_COMMANDS = COMMAND_MATCH_MAP.select { |_, v| v == // }.map(&:first)

  FLOAT_ERROR_DELTA = 1e-10

  attr_reader :commands

  def parse
    require_attributes 'd'

    @commands = []
    @last_point = nil

    data = attributes["d"].gsub(/#{OUTSIDE_SPACE_REGEXP}$/, '')

    matched_commands = match_all(data, COMMAND_REGEXP)
    raise SkipElementError, "Invalid/unsupported syntax for SVG path data" if matched_commands.nil?

    matched_commands.each do |(command, parameters)|
      regexp = COMMAND_MATCH_MAP[command.upcase] or break
      matched_values = match_all(parameters, regexp) or break
      values = matched_values.map { |value| value.map(&:to_f) }
      break if values.empty? && !PARAMETERLESS_COMMANDS.include?(command.upcase)

      parse_path_command(command, values)
    end
  end

  def apply
    add_call 'join_style', :bevel

    apply_commands
    apply_markers
  end

  protected

  def parse_path_command(command, values)
    upcase_command = command.upcase
    relative = command != upcase_command

    case upcase_command
    when 'M' # moveto
      x, y = values.shift

      if relative && @last_point
        x += @last_point.first
        y += @last_point.last
      end

      @subpath_initial_point = [x, y]
      push_command Prawn::SVG::Pathable::Move.new(@subpath_initial_point)

      return parse_path_command(relative ? 'l' : 'L', values) if values.any?

    when 'Z' # closepath
      if @subpath_initial_point
        push_command Prawn::SVG::Pathable::Close.new(@subpath_initial_point)
      end

    when 'L' # lineto
      while values.any?
        x, y = values.shift
        if relative && @last_point
          x += @last_point.first
          y += @last_point.last
        end

        push_command Prawn::SVG::Pathable::Line.new([x, y])
      end

    when 'H' # horizontal lineto
      while values.any?
        x = values.shift.first
        x += @last_point.first if relative && @last_point
        push_command Prawn::SVG::Pathable::Line.new([x, @last_point.last])
      end

    when 'V' # vertical lineto
      while values.any?
        y = values.shift.first
        y += @last_point.last if relative && @last_point
        push_command Prawn::SVG::Pathable::Line.new([@last_point.first, y])
      end

    when 'C' # curveto
      while values.any?
        x1, y1, x2, y2, x, y = values.shift

        if relative && @last_point
          x += @last_point.first
          x1 += @last_point.first
          x2 += @last_point.first
          y += @last_point.last
          y1 += @last_point.last
          y2 += @last_point.last
        end

        @previous_control_point = [x2, y2]
        push_command Prawn::SVG::Pathable::Curve.new([x, y], [x1, y1], [x2, y2])
      end

    when 'S' # shorthand/smooth curveto
      while values.any?
        x2, y2, x, y = values.shift

        if relative && @last_point
          x += @last_point.first
          x2 += @last_point.first
          y += @last_point.last
          y2 += @last_point.last
        end

        if @previous_control_point
          x1 = 2 * @last_point.first - @previous_control_point.first
          y1 = 2 * @last_point.last - @previous_control_point.last
        else
          x1, y1 = @last_point
        end

        @previous_control_point = [x2, y2]
        push_command Prawn::SVG::Pathable::Curve.new([x, y], [x1, y1], [x2, y2])
      end

    when 'Q', 'T' # quadratic curveto
      while values.any?
        if shorthand = upcase_command == 'T'
          x, y = values.shift
        else
          x1, y1, x, y = values.shift
        end

        if relative && @last_point
          x += @last_point.first
          x1 += @last_point.first if x1
          y += @last_point.last
          y1 += @last_point.last if y1
        end

        if shorthand
          if @previous_quadratic_control_point
            x1 = 2 * @last_point.first - @previous_quadratic_control_point.first
            y1 = 2 * @last_point.last - @previous_quadratic_control_point.last
          else
            x1, y1 = @last_point
          end
        end

        # convert from quadratic to cubic
        cx1 = @last_point.first + (x1 - @last_point.first) * 2 / 3.0
        cy1 = @last_point.last + (y1 - @last_point.last) * 2 / 3.0
        cx2 = cx1 + (x - @last_point.first) / 3.0
        cy2 = cy1 + (y - @last_point.last) / 3.0

        @previous_quadratic_control_point = [x1, y1]

        push_command Prawn::SVG::Pathable::Curve.new([x, y], [cx1, cy1], [cx2, cy2])
      end

    when 'A'
      return unless @last_point

      while values.any?
        rx, ry, phi, fa, fs, x2, y2 = values.shift

        x1, y1 = @last_point

        return if rx.zero? && ry.zero?

        if relative
          x2 += x1
          y2 += y1
        end

        # Normalise values as per F.6.2
        rx = rx.abs
        ry = ry.abs
        phi = (phi % 360) * 2 * Math::PI / 360.0

        # F.6.2: If the endpoints (x1, y1) and (x2, y2) are identical, then this is equivalent to omitting the elliptical arc segment entirely.
        return if within_float_delta?(x1, x2) && within_float_delta?(y1, y2)

        # F.6.2: If rx = 0 or ry = 0 then this arc is treated as a straight line segment (a "lineto") joining the endpoints.
        if within_float_delta?(rx, 0) || within_float_delta?(ry, 0)
          push_command Prawn::SVG::Pathable::Line.new([x2, y2])
          return
        end

        # We need to get the center co-ordinates, as well as the angles from the X axis to the start and end
        # points.  To do this, we use the algorithm documented in the SVG specification section F.6.5.

        # F.6.5.1
        xp1 = Math.cos(phi) * ((x1-x2)/2.0) + Math.sin(phi) * ((y1-y2)/2.0)
        yp1 = -Math.sin(phi) * ((x1-x2)/2.0) + Math.cos(phi) * ((y1-y2)/2.0)

        # F.6.6.2
        r2x = rx * rx
        r2y = ry * ry
        hat = xp1 * xp1 / r2x + yp1 * yp1 / r2y
        if hat > 1
          rx *= Math.sqrt(hat)
          ry *= Math.sqrt(hat)
        end

        # F.6.5.2
        r2x = rx * rx
        r2y = ry * ry
        square = (r2x * r2y - r2x * yp1 * yp1 - r2y * xp1 * xp1) / (r2x * yp1 * yp1 + r2y * xp1 * xp1)
        square = 0 if square < 0 && square > -FLOAT_ERROR_DELTA # catch rounding errors
        base = Math.sqrt(square)
        base *= -1 if fa == fs
        cpx = base * rx * yp1 / ry
        cpy = base * -ry * xp1 / rx

        # F.6.5.3
        cx = Math.cos(phi) * cpx + -Math.sin(phi) * cpy + (x1 + x2) / 2
        cy = Math.sin(phi) * cpx + Math.cos(phi) * cpy + (y1 + y2) / 2

        # F.6.5.5
        vx = (xp1 - cpx) / rx
        vy = (yp1 - cpy) / ry
        theta_1 = Math.acos(vx / Math.sqrt(vx * vx + vy * vy))
        theta_1 *= -1 if vy < 0

        # F.6.5.6
        ux = vx
        uy = vy
        vx = (-xp1 - cpx) / rx
        vy = (-yp1 - cpy) / ry

        numerator = ux * vx + uy * vy
        denominator = Math.sqrt(ux * ux + uy * uy) * Math.sqrt(vx * vx + vy * vy)
        division = numerator / denominator
        division = -1 if division < -1 # for rounding errors

        d_theta = Math.acos(division) % (2 * Math::PI)
        d_theta *= -1 if ux * vy - uy * vx < 0

        # Adjust range
        if fs == 0
          d_theta -= 2 * Math::PI if d_theta > 0
        else
          d_theta += 2 * Math::PI if d_theta < 0
        end

        theta_2 = theta_1 + d_theta

        calculate_bezier_curve_points_for_arc(cx, cy, rx, ry, theta_1, theta_2, phi).each do |points|
          push_command Prawn::SVG::Pathable::Curve.new(points[:p2], points[:q1], points[:q2])
        end
      end
    end

    @previous_control_point = nil unless %w(C S).include?(upcase_command)
    @previous_quadratic_control_point = nil unless %w(Q T).include?(upcase_command)
  end

  def within_float_delta?(a, b)
    (a - b).abs < FLOAT_ERROR_DELTA
  end

  def match_all(string, regexp) # regexp must start with ^
    result = []
    while string != ""
      matches = string.match(regexp) or return
      result << matches.captures
      string = matches.post_match
    end
    result
  end

  def push_command(command)
    @commands << command
    @last_point = command.destination
  end
end
