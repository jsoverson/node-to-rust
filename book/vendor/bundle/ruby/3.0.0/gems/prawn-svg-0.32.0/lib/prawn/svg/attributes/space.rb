module Prawn::SVG::Attributes::Space
  def parse_xml_space_attribute
    case attributes['xml:space']
    when 'preserve'
      state.preserve_space = true
    when 'default'
      state.preserve_space = false
    end
  end
end
