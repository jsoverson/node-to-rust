module Prawn::SVG::Pathable
  Move = Struct.new(:destination)
  Close = Struct.new(:destination)
  Line = Struct.new(:destination)
  Curve = Struct.new(:destination, :point1, :point2)

  def bounding_box
    points = commands.map { |command| translate(command.destination) }
    x1, x2 = points.map(&:first).minmax
    y2, y1 = points.map(&:last).minmax

    [x1, y1, x2, y2]
  end

  protected

  def apply_commands
    commands.each do |command|
      case command
      when Move
        add_call 'move_to', translate(command.destination)
      when Close
        add_call 'close_path'
      when Line
        add_call 'line_to', translate(command.destination)
      when Curve
        add_call 'curve_to', translate(command.destination), bounds: [translate(command.point1), translate(command.point2)]
      else
        raise NotImplementedError, "Unknown path command type"
      end
    end
  end

  def apply_markers
    if marker = extract_element_from_url_id_reference(properties.marker_start, "marker")
      marker.apply_marker(self, point: commands.first.destination, angle: angles.first)
    end

    if marker = extract_element_from_url_id_reference(properties.marker_mid, "marker")
      (1..commands.length-2).each do |index|
        marker.apply_marker(self, point: commands[index].destination, angle: angles[index])
      end
    end

    if marker = extract_element_from_url_id_reference(properties.marker_end, "marker")
      marker.apply_marker(self, point: commands.last.destination, angle: angles.last)
    end
  end

  def angles
    return @angles if @angles

    last_point = nil

    destination_angles = commands.map do |command|
      angles = case command
      when Move
        [nil, nil]
      when Close, Line
        angle = Math.atan2(command.destination[1] - last_point[1], command.destination[0] - last_point[0]) * 180.0 / Math::PI
        [angle, angle]
      when Curve
        point = select_non_equal_point(last_point, command.point1, command.point2, command.destination)
        start = Math.atan2(point[1] - last_point[1], point[0] - last_point[0]) * 180.0 / Math::PI

        point = select_non_equal_point(command.destination, command.point2, command.point1, last_point)
        stop = Math.atan2(command.destination[1] - point[1], command.destination[0] - point[0]) * 180.0 / Math::PI

        [start, stop]
      else
        raise NotImplementedError, "Unknown path command type"
      end

      last_point = command.destination
      angles
    end

    angles = destination_angles.each_cons(2).map do |first_angles, second_angles|
      if first_angles.first.nil?
        second_angles.first || 0
      elsif second_angles.first.nil?
        first_angles.last
      else
        first = first_angles.last
        second = second_angles.last
        bisect = (first + second) / 2.0

        if (first - second).abs > 180
          bisect >= 0 ? bisect - 180 : bisect + 180
        else
          bisect
        end
      end
    end

    if commands.last.is_a?(Close)
      first = destination_angles.last.last || 0
      second = angles.first
      bisect = (first + second) / 2.0

      angles << if (first - second).abs > 180
        bisect >= 0 ? bisect - 180 : bisect + 180
      else
        bisect
      end
    else
      angles << destination_angles.last.last
    end

    @angles = angles
  end

  def parse_points(points_string)
    values = points_string.
      to_s.
      strip.
      gsub(/(\d)-(\d)/, '\1 -\2').
      split(Prawn::SVG::Elements::COMMA_WSP_REGEXP).
      map(&:to_f)

    if values.length % 2 == 1
      document.warnings << "points attribute has an odd number of points; ignoring the last one"
      values.pop
    end

    raise Prawn::SVG::Elements::Base::SkipElementQuietly if values.length == 0

    values.each_slice(2).to_a
  end

  def translate(point)
    [point[0].to_f, document.sizing.output_height - point[1].to_f]
  end

  private

  def select_non_equal_point(base, point_a, point_b, point_c)
    if point_a != base
      point_a
    elsif point_b != base
      point_b
    else
      point_c
    end
  end
end
