# frozen_string_literal: true

module PDF::Core
  class << self
    alias _initial_real real

    # NOTE Makes v1.6.x work with the modified precision settings (0.5f) in Prawn 2.4 while preserving existing behavior
    def real num, precision = 4
      ("%.#{precision}f" % num).sub(/((?<!\.)0)+\z/, '')
    end

    alias _initial_real_params real_params
    def real_params array
      return array.map {|e| real e, 5 }.join(' ') if (caller_locations 1, 1)[0].base_label == 'transformation_matrix'
      _initial_real_params array
    end
  end
end

require_relative 'pdf-core/pdf_object'
require_relative 'pdf-core/page'
