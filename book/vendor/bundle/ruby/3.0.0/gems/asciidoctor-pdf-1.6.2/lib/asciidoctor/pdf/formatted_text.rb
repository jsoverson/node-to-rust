# frozen_string_literal: true

require 'treetop'
require 'set' unless defined? Set
require_relative 'formatted_text/parser'
require_relative 'formatted_text/transform'
require_relative 'formatted_text/formatter'
require_relative 'formatted_text/fragment_position_renderer'
require_relative 'formatted_text/inline_destination_marker'
require_relative 'formatted_text/inline_image_arranger'
require_relative 'formatted_text/inline_image_renderer'
require_relative 'formatted_text/inline_text_aligner'
require_relative 'formatted_text/source_wrap'
require_relative 'formatted_text/text_background_and_border_renderer'
