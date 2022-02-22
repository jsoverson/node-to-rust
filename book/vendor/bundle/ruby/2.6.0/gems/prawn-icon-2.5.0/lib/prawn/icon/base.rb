# encoding: utf-8
#
# base.rb - Base configuration for Prawn::Icon.
#
# Copyright September 2016, Jesse Doyle. All rights reserved.
#
# This is free software. Please see the LICENSE and COPYING files for details.

require 'prawn'
require_relative 'errors'

module Prawn
  class Icon
    module Base
      FONTDIR = File.join \
        File.expand_path('../../../..', __FILE__), 'data/fonts'
    end
  end
end
