class Prawn::SVG::Elements::Line < Prawn::SVG::Elements::Base
  include Prawn::SVG::Pathable

  def parse
    # Lines are one dimensional, so cannot be filled.
    computed_properties.fill = 'none'

    @x1 = x_pixels(attributes['x1'] || 0)
    @y1 = y_pixels(attributes['y1'] || 0)
    @x2 = x_pixels(attributes['x2'] || 0)
    @y2 = y_pixels(attributes['y2'] || 0)
  end

  def apply
    apply_commands
    apply_markers
  end

  protected

  def commands
    @commands ||= [
      Prawn::SVG::Pathable::Move.new([@x1, @y1]),
      Prawn::SVG::Pathable::Line.new([@x2, @y2])
    ]
  end
end
