# frozen_string_literal: true

class Asciidoctor::Document
  alias catalog references unless method_defined? :catalog
end
