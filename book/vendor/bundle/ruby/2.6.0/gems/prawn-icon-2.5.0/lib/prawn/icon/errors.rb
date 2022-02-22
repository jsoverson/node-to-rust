# encoding: utf-8
#
# errors.rb - Prawn::Icon standard errors.
#
# Copyright September 2016, Jesse Doyle. All rights reserved.
#
# This is free software. Please see the LICENSE and COPYING files for details.

module Prawn
  class Icon
    module Errors
      # Error raised when an icon glyph is not found
      #
      IconNotFound = Class.new(StandardError)

      # Error raised when an icon key is not provided
      #
      IconKeyEmpty = Class.new(StandardError)
    end
  end
end
