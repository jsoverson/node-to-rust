module Prawn::SVG::Elements
  COMMA_WSP_REGEXP = /(?:\s+,?\s*|,\s*)/
end

require 'prawn/svg/elements/call_duplicator'

%w(base depth_first_base root container clip_path viewport text text_component line polyline polygon circle ellipse rect path use image gradient marker ignored).each do |filename|
  require "prawn/svg/elements/#{filename}"
end

module Prawn::SVG::Elements
  TAG_CLASS_MAPPING = {
    g: Prawn::SVG::Elements::Container,
    symbol: Prawn::SVG::Elements::Container,
    defs: Prawn::SVG::Elements::Container,
    a: Prawn::SVG::Elements::Container,
    clipPath: Prawn::SVG::Elements::ClipPath,
    switch: Prawn::SVG::Elements::Container,
    svg: Prawn::SVG::Elements::Viewport,
    text: Prawn::SVG::Elements::Text,
    line: Prawn::SVG::Elements::Line,
    polyline: Prawn::SVG::Elements::Polyline,
    polygon: Prawn::SVG::Elements::Polygon,
    circle: Prawn::SVG::Elements::Circle,
    ellipse: Prawn::SVG::Elements::Ellipse,
    rect: Prawn::SVG::Elements::Rect,
    path: Prawn::SVG::Elements::Path,
    use: Prawn::SVG::Elements::Use,
    image: Prawn::SVG::Elements::Image,
    linearGradient: Prawn::SVG::Elements::Gradient,
    radialGradient: Prawn::SVG::Elements::Gradient,
    marker: Prawn::SVG::Elements::Marker,
    style: Prawn::SVG::Elements::Ignored, # because it is pre-parsed by Document
    title: Prawn::SVG::Elements::Ignored,
    desc: Prawn::SVG::Elements::Ignored,
    metadata: Prawn::SVG::Elements::Ignored,
    foreignObject: Prawn::SVG::Elements::Ignored,
    :"font-face" => Prawn::SVG::Elements::Ignored,
    filter: Prawn::SVG::Elements::Ignored, # unsupported
  }
end
