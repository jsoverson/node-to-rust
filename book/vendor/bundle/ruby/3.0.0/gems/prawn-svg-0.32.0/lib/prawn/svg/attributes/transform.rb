module Prawn::SVG::Attributes::Transform
  def parse_transform_attribute_and_call
    return unless transform = attributes['transform']

    matrix = parse_transform_attribute(transform)
    add_call_and_enter "transformation_matrix", *matrix unless matrix == [1, 0, 0, 1, 0, 0]
  end
end
