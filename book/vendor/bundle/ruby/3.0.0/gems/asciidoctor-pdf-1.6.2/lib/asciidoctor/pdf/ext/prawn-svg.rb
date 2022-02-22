# frozen_string_literal: true

require 'prawn-svg' unless defined? Prawn::SVG::Interface
# NOTE disable system fonts since they're non-portable
Prawn::SVG::Interface.font_path.clear
