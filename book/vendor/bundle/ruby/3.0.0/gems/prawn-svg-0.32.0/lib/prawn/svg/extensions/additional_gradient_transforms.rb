module Prawn::SVG::Extensions
  module AdditionalGradientTransforms
    def gradient_coordinates(gradient)
      # As of Prawn 2.2.0, apply_transformations is used as purely a boolean.
      #
      # Here we're using it to optionally pass in a 6-tuple transformation matrix that gets applied to the
      # gradient.  This should be added to Prawn properly, and then this monkey patch will not be necessary.

      if gradient.apply_transformations.is_a?(Array)
        x1, y1, x2, y2, transformation = super
        a, b, c, d, e, f = transformation
        na, nb, nc, nd, ne, nf = gradient.apply_transformations

        matrix = Matrix[[a, c, e], [b, d, f], [0, 0, 1]] * Matrix[[na, nc, ne], [nb, nd, nf], [0, 0, 1]]
        new_transformation = matrix.to_a[0..1].transpose.flatten

        [x1, y1, x2, y2, new_transformation]
      else
        super
      end
    end
  end
end
