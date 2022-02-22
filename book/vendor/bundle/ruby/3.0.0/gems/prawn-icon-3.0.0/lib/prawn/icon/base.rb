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
    class << self
      attr_writer :configuration

      def configuration
        @configuration ||= Configuration.new
      end

      def configure
        yield(configuration)
      end
    end

    module Base
      # @deprecated Use {Prawn::Icon.configuration.font_directory} instead
      FONTDIR = Prawn::Icon.configuration.font_directory.to_s
    end
  end
end
