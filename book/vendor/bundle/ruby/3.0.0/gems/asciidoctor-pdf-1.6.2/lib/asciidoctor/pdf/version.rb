# frozen_string_literal: true

module Asciidoctor
  module PDF
    VERSION = '1.6.2'
  end
  Pdf = PDF unless const_defined? :Pdf, false
end
