module Prawn::SVG::Calculators
  module ArcToBezierCurve
    protected

    # Convert the elliptical arc to a cubic bézier curve using this algorithm:
    # http://www.spaceroots.org/documents/ellipse/elliptical-arc.pdf
    def calculate_bezier_curve_points_for_arc(cx, cy, a, b, lambda_1, lambda_2, theta)
      e = lambda do |eta|
        [
          cx + a * Math.cos(theta) * Math.cos(eta) - b * Math.sin(theta) * Math.sin(eta),
          cy + a * Math.sin(theta) * Math.cos(eta) + b * Math.cos(theta) * Math.sin(eta)
        ]
      end

      ep = lambda do |eta|
        [
          -a * Math.cos(theta) * Math.sin(eta) - b * Math.sin(theta) * Math.cos(eta),
          -a * Math.sin(theta) * Math.sin(eta) + b * Math.cos(theta) * Math.cos(eta)
        ]
      end

      iterations = 1
      d_lambda = lambda_2 - lambda_1

      while iterations < 1024
        if d_lambda.abs <= Math::PI / 2.0
          # TODO : run error algorithm, see whether it meets threshold or not
          # puts "error = #{calculate_curve_approximation_error(a, b, eta1, eta1 + d_eta)}"
          break
        end
        iterations *= 2
        d_lambda = (lambda_2 - lambda_1) / iterations
      end

      (0...iterations).collect do |iteration|
        eta_a, eta_b = calculate_eta_from_lambda(a, b, lambda_1+iteration*d_lambda, lambda_1+(iteration+1)*d_lambda)
        d_eta = eta_b - eta_a

        alpha = Math.sin(d_eta) * ((Math.sqrt(4 + 3 * Math.tan(d_eta / 2) ** 2) - 1) / 3)

        x1, y1 = e[eta_a]
        x2, y2 = e[eta_b]

        ep_eta1_x, ep_eta1_y = ep[eta_a]
        q1_x = x1 + alpha * ep_eta1_x
        q1_y = y1 + alpha * ep_eta1_y

        ep_eta2_x, ep_eta2_y = ep[eta_b]
        q2_x = x2 - alpha * ep_eta2_x
        q2_y = y2 - alpha * ep_eta2_y

        {:p2 => [x2, y2], :q1 => [q1_x, q1_y], :q2 => [q2_x, q2_y]}
      end
    end

    private

    ERROR_COEFFICIENTS_A = [
      [
        [3.85268, -21.229, -0.330434, 0.0127842],
        [-1.61486, 0.706564, 0.225945, 0.263682],
        [-0.910164, 0.388383, 0.00551445, 0.00671814],
        [-0.630184, 0.192402, 0.0098871, 0.0102527]
      ],
      [
        [-0.162211, 9.94329, 0.13723, 0.0124084],
        [-0.253135, 0.00187735, 0.0230286, 0.01264],
        [-0.0695069, -0.0437594, 0.0120636, 0.0163087],
        [-0.0328856, -0.00926032, -0.00173573, 0.00527385]
      ]
    ]

    ERROR_COEFFICIENTS_B = [
      [
        [0.0899116, -19.2349, -4.11711, 0.183362],
        [0.138148, -1.45804, 1.32044, 1.38474],
        [0.230903, -0.450262, 0.219963, 0.414038],
        [0.0590565, -0.101062, 0.0430592, 0.0204699]
      ],
      [
        [0.0164649, 9.89394, 0.0919496, 0.00760802],
        [0.0191603, -0.0322058, 0.0134667, -0.0825018],
        [0.0156192, -0.017535, 0.00326508, -0.228157],
        [-0.0236752, 0.0405821, -0.0173086, 0.176187]
      ]
    ]

    def calculate_curve_approximation_error(a, b, eta1, eta2)
      b_over_a = b / a
      coefficents = b_over_a < 0.25 ? ERROR_COEFFICIENTS_A : ERROR_COEFFICIENTS_B

      c = lambda do |i|
        (0..3).inject(0) do |accumulator, j|
          coef = coefficents[i][j]
          accumulator + ((coef[0] * b_over_a**2 + coef[1] * b_over_a + coef[2]) / (b_over_a * coef[3])) * Math.cos(j * (eta1 + eta2))
        end
      end

      ((0.001 * b_over_a**2 + 4.98 * b_over_a + 0.207) / (b_over_a * 0.0067)) * a * Math.exp(c[0] + c[1] * (eta2 - eta1))
    end

    def calculate_eta_from_lambda(a, b, lambda_1, lambda_2)
      # 2.2.1
      eta1 = Math.atan2(Math.sin(lambda_1) / b, Math.cos(lambda_1) / a)
      eta2 = Math.atan2(Math.sin(lambda_2) / b, Math.cos(lambda_2) / a)

      # ensure eta1 <= eta2 <= eta1 + 2*PI
      eta2 -= 2 * Math::PI * ((eta2 - eta1) / (2 * Math::PI)).floor
      eta2 += 2 * Math::PI if lambda_2 - lambda_1 > Math::PI && eta2 - eta1 < Math::PI

      [eta1, eta2]
    end
  end
end
