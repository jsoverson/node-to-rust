# frozen_string_literal: true

module Pygments
  module Ext
    module BlockStyles
      BlockSelectorRx = /^\.highlight *\{([^}]+?)\}/
      HighlightBackgroundColorRx = /^\.highlight +\.hll +{ *background(?:-color)?: *#([a-fA-F0-9]{6})/
      ColorPropertiesRx = /(?:^|;) *(background(?:-color)?|color): *#?([a-fA-F0-9]{6}) *(?=$|;)/

      @cache = ::Hash.new do |cache, key|
        styles = {}
        if BlockSelectorRx =~ (css = ::Pygments.css '.highlight', style: key)
          $1.scan ColorPropertiesRx do |pname, pval|
            case pname
            when 'background', 'background-color'
              styles[:background_color] = pval
            when 'color'
              styles[:font_color] = pval
            end
          end
        end
        styles[:highlight_background_color] = $1 if HighlightBackgroundColorRx =~ css
        @cache = cache.merge key => styles
        styles
      end

      def self.available? style
        (@available ||= ::Pygments.styles.to_set).include? style
      end

      def self.for style
        @cache[style]
      end
    end
  end
end
