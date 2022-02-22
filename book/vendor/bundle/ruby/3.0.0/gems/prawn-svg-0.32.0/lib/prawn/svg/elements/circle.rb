class Prawn::SVG::Elements::Circle < Prawn::SVG::Elements::Base
  USE_NEW_CIRCLE_CALL = Prawn::Document.instance_methods.include?(:circle)

  def parse
    require_attributes 'r'

    @x = x(attributes['cx'] || "0")
    @y = y(attributes['cy'] || "0")
    @r = pixels(attributes['r'])

    require_positive_value @r
  end

  def apply
    if USE_NEW_CIRCLE_CALL
      add_call "circle", [@x, @y], @r
    else
      add_call "circle_at", [@x, @y], radius: @r
    end
  end

  def bounding_box
    [@x - @r, @y + @r, @x + @r, @y - @r]
  end
end
