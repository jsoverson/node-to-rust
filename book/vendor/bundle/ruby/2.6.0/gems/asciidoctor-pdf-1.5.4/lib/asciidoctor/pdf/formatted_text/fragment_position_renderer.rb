# frozen_string_literal: true

module Asciidoctor::PDF::FormattedText
  class FragmentPositionRenderer
    attr_reader :top
    attr_reader :right
    attr_reader :bottom
    attr_reader :left
    attr_reader :page_number

    def render_behind fragment
      @top = fragment.top
      @right = (@left = fragment.left) + fragment.width
      @bottom = fragment.bottom
      @page_number = fragment.document.page_number
    end
  end
end
