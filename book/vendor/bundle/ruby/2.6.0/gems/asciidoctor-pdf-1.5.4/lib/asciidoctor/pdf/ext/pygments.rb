# frozen_string_literal: true

require 'pygments.rb' # rubocop:disable Style/RedundantFileExtensionInRequire

module Pygments
  module Ext
    module BlockStyles
      BlockSelectorRx = /^\.highlight *\{([^}]+?)\}/
      HighlightBackgroundColorRx = /^\.highlight +\.hll +{ *background(?:-color)?: *#([a-fA-F0-9]{6})/
      HexColorRx = /^#[a-fA-F0-9]{6}$/

      @cache = ::Hash.new do |cache, key|
        styles = {}
        if BlockSelectorRx =~ (css = ::Pygments.css '.highlight', style: key)
          ($1.strip.split ';').each do |style|
            pname, pval = (style.split ':', 2).map(&:strip)
            case pname
            when 'background', 'background-color'
              styles[:background_color] = pval.slice 1, pval.length if HexColorRx.match? pval
            when 'color'
              styles[:font_color] = pval.slice 1, pval.length if HexColorRx.match? pval
            end
          end
        end
        styles[:highlight_background_color] = $1 if HighlightBackgroundColorRx =~ css
        @cache = cache.merge key => styles
        styles
      end

      def self.for style
        @cache[style]
      end
    end
  end
end
