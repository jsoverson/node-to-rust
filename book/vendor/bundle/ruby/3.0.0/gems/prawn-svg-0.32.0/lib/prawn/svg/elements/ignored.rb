class Prawn::SVG::Elements::Ignored < Prawn::SVG::Elements::Base
  def parse
    raise SkipElementQuietly
  end
end
