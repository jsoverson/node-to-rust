# encoding: utf-8
#
# configuration.rb: Prawn icon configuration.
#
# Copyright October 2020, Jesse Doyle. All rights reserved.
#
# This is free software. Please see the LICENSE and COPYING files for details.

module Prawn
  class Icon
    class Configuration
      def font_directory=(path)
        @font_directory = Pathname.new(path)
      end

      def font_directory
        @font_directory ||= default_font_directory
      end

      private

      def default_font_directory
        Pathname.new(gem_path).join('data', 'fonts')
      end

      # :nocov:
      def gem_path
        spec = Gem.loaded_specs.fetch('prawn-icon') do
          Struct.new(:full_gem_path).new(failsafe_gem_path)
        end
        spec.full_gem_path
      end

      def failsafe_gem_path
        File.expand_path('../../../..', __FILE__)
      end
      # :nocov:
    end
  end
end
