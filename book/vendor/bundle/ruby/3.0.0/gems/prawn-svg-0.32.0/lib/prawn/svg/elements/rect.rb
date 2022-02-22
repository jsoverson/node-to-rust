class Prawn::SVG::Elements::Rect < Prawn::SVG::Elements::Base
  def parse
    require_attributes 'width', 'height'

    @x = x(attributes['x'] || '0')
    @y = y(attributes['y'] || '0')
    @width = x_pixels(attributes['width'])
    @height = y_pixels(attributes['height'])

    require_positive_value @width, @height

    @radius = x_pixels(attributes['rx']) || y_pixels(attributes['ry'])
    if @radius
      # If you implement separate rx and ry in the future, you'll want to change this
      # so that rx is constrained to @width/2 and ry is constrained to @height/2.
      max_value = [@width, @height].min / 2.0
      @radius = clamp(@radius, 0, max_value)
    end
  end

  def apply
    if @radius
      # n.b. does not support both rx and ry being specified with different values
      add_call "rounded_rectangle", [@x, @y], @width, @height, @radius
    else
      add_call "rectangle", [@x, @y], @width, @height
    end
  end

  def bounding_box
    [@x, @y, @x + @width, @y - @height]
  end
end
