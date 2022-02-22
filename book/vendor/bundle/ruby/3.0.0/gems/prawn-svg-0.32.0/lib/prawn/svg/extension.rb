module Prawn
  module SVG
    module Extension
      #
      # Draws an SVG document into the PDF.
      #
      # +options+ must contain the key :at, which takes a tuple of x and y co-ordinates.
      #
      # +options+ can optionally contain the key :width or :height.  If both are
      # specified, only :width will be used.  If neither are specified, the resolution
      # given in the SVG will be used.
      #
      # Example usage:
      #
      #   svg IO.read("example.svg"), :at => [100, 300], :width => 600
      #
      def svg(data, options = {}, &block)
        svg = Prawn::SVG::Interface.new(data, self, options, &block)
        svg.draw
        {:warnings => svg.document.warnings, :width => svg.document.sizing.output_width, :height => svg.document.sizing.output_height}
      end
    end
  end
end
