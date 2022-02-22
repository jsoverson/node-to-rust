module Prawn::SVG::Attributes::ClipPath
  def parse_clip_path_attribute_and_call
    return unless clip_path = properties.clip_path
    return if clip_path == 'none'

    clip_path_element = extract_element_from_url_id_reference(clip_path, 'clipPath')

    if clip_path_element.nil?
      document.warnings << "Could not resolve clip-path URI to a clipPath element"
    else
      add_call_and_enter 'save_graphics_state'
      add_calls_from_element clip_path_element
      add_call "clip"
    end
  end
end
