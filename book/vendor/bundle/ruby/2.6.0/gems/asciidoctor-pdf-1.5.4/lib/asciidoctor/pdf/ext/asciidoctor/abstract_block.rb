# frozen_string_literal: true

class Asciidoctor::AbstractBlock
  def sections?
    !sections.empty?
  end unless method_defined? :sections?
end
