# frozen_string_literal: true

module Asciidoctor
  module PDF
    module Measurements
      MeasurementValueRx = /(\d+|\d*\.\d+)(in|mm|cm|p[txc])?$/
      InsetMeasurementValueRx = /(?<=^| |\()(-?\d+(?:\.\d+)?)(in|mm|cm|p[txc])(?=$| |\))/
      MeasurementValueHintRx = /\d(in|mm|cm|p[txc])/

      # Convert the specified string value to a pt value from the
      # specified unit of measurement (e.g., in, cm, mm, etc).
      # If the unit of measurement is not recognized, assume pt.
      #
      # Examples:
      #
      #  0.5in => 36.0
      #  100px => 75.0
      #  72blah => 72.0
      #
      def str_to_pt val
        MeasurementValueRx =~ val ? (to_pt $1.to_f, $2) : val.to_f
      end

      # Converts the specified float value to a pt value from the
      # specified unit of measurement (e.g., in, cm, mm, etc).
      # Raises an argument error if the unit of measurement is not recognized.
      def to_pt num, units
        units = units.to_s if ::Symbol === units
        if units.nil_or_empty?
          num
        else
          case units
          when 'pt'
            num
          when 'in'
            num * 72
          when 'mm'
            num * (72 / 25.4)
          when 'cm'
            num * (720 / 25.4)
          when 'px'
            # assuming canvas of 96 dpi
            num * 0.75
          when 'pc'
            num * 12
          else
            raise ::ArgumentError, %(unknown unit of measurement: #{units})
          end
        end
      end

      # Resolve measurement values in the string to PDF points.
      def resolve_measurement_values str
        if MeasurementValueHintRx.match? str
          str.gsub(InsetMeasurementValueRx) { to_pt $1.to_f, $2 }
        else
          str
        end
      end
    end
  end
end
