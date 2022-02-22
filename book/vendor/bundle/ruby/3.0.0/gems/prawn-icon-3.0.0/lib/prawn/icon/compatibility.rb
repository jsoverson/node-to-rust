# encoding: utf-8
#
# compatibility.rb - Prawn::Icon FontAwesome 4/5 compatibility shim.
#
# Copyright March 2018, Jesse Doyle. All rights reserved.
#
# This is free software. Please see the LICENSE and COPYING files for details.

module Prawn
  class Icon
    class Compatibility
      # @deprecated Use {Prawn::Icon::Compatibility.shims} instead
      SHIMS = YAML.load_file(
        Prawn::Icon.configuration.font_directory.join(
          'fa4',
          'shims.yml'
        )
      ).freeze

      class << self
        def shims
          @shims ||= YAML.load_file(
            Icon.configuration.font_directory.join('fa4', 'shims.yml').to_s
          )
        end
      end

      attr_accessor :key

      def initialize(opts = {})
        self.key = opts.fetch(:key)
      end

      def translate(io = STDERR)
        @translate ||= begin
          if key.start_with?('fa-')
            map.tap { |replaced| warning(replaced, key, io) }
          else
            key
          end
        end
      end

      private

      def map
        self.class.shims.fetch(key) do
          # FontAwesome shim metadata assumes "fas" as the default
          # font family if not explicity referenced.
          "fas-#{key.sub(/fa-/, '')}"
        end
      end

      def warning(new_key, old_key, io)
        io.puts <<-DEPRECATION
[Prawn::Icon - DEPRECATION WARNING]
  FontAwesome 4 icon was referenced as '#{old_key}'.
  Use the FontAwesome 5 icon '#{new_key}' instead.
  This compatibility layer will be removed in Prawn::Icon 4.0.0.
DEPRECATION
      end
    end
  end
end
# rubocop:enable Metrics/ClassLength
