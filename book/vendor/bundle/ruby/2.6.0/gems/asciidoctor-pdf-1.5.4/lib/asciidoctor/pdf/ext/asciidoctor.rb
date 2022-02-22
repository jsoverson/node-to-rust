# frozen_string_literal: true

# NOTE these are either candidates for inclusion in Asciidoctor core or backports
require_relative 'asciidoctor/logging_shim' unless defined? Asciidoctor::Logging
require_relative 'asciidoctor/abstract_node'
require_relative 'asciidoctor/abstract_block'
require_relative 'asciidoctor/document'
require_relative 'asciidoctor/section'
require_relative 'asciidoctor/list'
require_relative 'asciidoctor/list_item'
require_relative 'asciidoctor/image'
