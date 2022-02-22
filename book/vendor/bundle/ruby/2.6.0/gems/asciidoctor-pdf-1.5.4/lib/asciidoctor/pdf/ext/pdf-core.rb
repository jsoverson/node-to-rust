# frozen_string_literal: true

module PDF::Core
  class << self
    alias _initial_real real
    def real num
      num.to_f.round 4
    end

    alias _initial_real_params real_params
    def real_params array
      return array.map {|it| it.to_f.round 5 }.join ' ' if (caller_locations 1, 1)[0].base_label == 'transformation_matrix'
      _initial_real_params array
    end
  end
end

require_relative 'pdf-core/pdf_object'
require_relative 'pdf-core/page'
