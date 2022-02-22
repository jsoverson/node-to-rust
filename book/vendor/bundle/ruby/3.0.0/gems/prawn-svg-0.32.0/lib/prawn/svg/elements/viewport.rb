class Prawn::SVG::Elements::Viewport < Prawn::SVG::Elements::Base
  def parse
    parent_dimensions = [state.viewport_sizing.viewport_width, state.viewport_sizing.viewport_height]

    @sizing = Prawn::SVG::Calculators::DocumentSizing.new(parent_dimensions, attributes)
    @sizing.calculate

    @x = x_pixels(attributes['x'] || 0)
    @y = y_pixels(attributes['y'] || 0)

    state.viewport_sizing = @sizing
  end

  def apply
    if @x != 0 || @y != 0
      add_call 'transformation_matrix', 1, 0, 0, 1, @x, -@y
    end

    add_call 'rectangle', [0, y(0)], @sizing.output_width, @sizing.output_height
    add_call 'clip'
    add_call 'transformation_matrix', @sizing.x_scale, 0, 0, @sizing.y_scale, 0, 0
    add_call 'transformation_matrix', 1, 0, 0, 1, -@sizing.x_offset, @sizing.y_offset
  end

  def container?
    true
  end
end
