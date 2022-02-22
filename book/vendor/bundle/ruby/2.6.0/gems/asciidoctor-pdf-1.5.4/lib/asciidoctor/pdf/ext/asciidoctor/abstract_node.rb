# frozen_string_literal: true

class Asciidoctor::AbstractNode
  def remove_attr name
    @attributes.delete name
  end unless method_defined? :remove_attr
end
