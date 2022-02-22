class Prawn::SVG::Elements::Marker < Prawn::SVG::Elements::Base
  def parse
    properties.display = 'none'
    computed_properties.display = 'none'
  end

  def container?
    true
  end

  def apply_marker(element, point: nil, angle: 0)
    sizing = Prawn::SVG::Calculators::DocumentSizing.new([0, 0], attributes)
    sizing.document_width = attributes["markerWidth"] || 3
    sizing.document_height = attributes["markerHeight"] || 3
    sizing.calculate

    if sizing.invalid?
      document.warnings << "<marker> cannot be rendered due to invalid sizing information"
      return
    end

    element.new_call_context_from_base do
      element.add_call 'save'

      # LATER : these will probably change when we separate out properties from attributes
      element.parse_transform_attribute_and_call
      element.parse_opacity_attributes_and_call
      element.parse_clip_path_attribute_and_call

      element.add_call 'transformation_matrix', 1, 0, 0, 1, point[0], -point[1]

      if attributes['orient'] != 'auto'
        angle = attributes['orient'].to_f # defaults to 0 if not specified
      end

      element.push_call_position
      element.add_call_and_enter 'rotate', -angle, origin: [0, y('0')] if angle != 0

      if attributes['markerUnits'] != 'userSpaceOnUse'
        scale = element.state.stroke_width
        element.add_call 'transformation_matrix', scale, 0, 0, scale, 0, 0
      end

      ref_x = x_pixels(attributes['refX']) || 0
      ref_y = y_pixels(attributes['refY']) || 0

      element.add_call 'transformation_matrix', 1, 0, 0, 1, -ref_x * sizing.x_scale, ref_y * sizing.y_scale

      # `overflow: visible` must be on the <marker> element
      if properties.overflow != 'visible'
        point = [sizing.x_offset * sizing.x_scale, y(sizing.y_offset * sizing.y_scale)]
        element.add_call "rectangle", point, sizing.output_width, sizing.output_height
        element.add_call "clip"
      end

      element.add_call 'transformation_matrix', sizing.x_scale, 0, 0, sizing.y_scale, 0, 0

      new_state = state.dup
      new_state.computed_properties = computed_properties.dup

      container = Prawn::SVG::Elements::Container.new(document, nil, [], new_state)
      container.properties.compute_properties(new_state.computed_properties)
      container.parse_and_apply
      container.add_calls_from_element(self)

      element.add_calls_from_element(container)

      element.pop_call_position
      element.add_call 'restore'
    end
  end
end
