class Prawn::SVG::Elements::ClipPath < Prawn::SVG::Elements::Base
  def parse
    state.inside_clip_path = true
    properties.display = 'none'
    computed_properties.display = 'none'
  end

  def container?
    true
  end
end

