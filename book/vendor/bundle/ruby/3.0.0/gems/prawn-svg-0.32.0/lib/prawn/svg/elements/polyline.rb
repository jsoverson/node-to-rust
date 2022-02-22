class Prawn::SVG::Elements::Polyline < Prawn::SVG::Elements::Base
  include Prawn::SVG::Pathable

  def parse
    require_attributes('points')
    @points = parse_points(attributes['points'])
  end

  def apply
    apply_commands
    apply_markers
  end

  protected

  def commands
    @commands ||= [
      Prawn::SVG::Pathable::Move.new(@points[0])
    ] + @points[1..-1].map { |point|
      Prawn::SVG::Pathable::Line.new(point)
    }
  end
end
