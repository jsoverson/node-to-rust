# frozen_string_literal: true

module Asciidoctor
  module PDF
    module FormattedText
      class Transform
        LF = ?\n
        ZeroWidthSpace = ?\u200b
        CharEntityTable = { amp: ?&, apos: ?', gt: ?>, lt: ?<, nbsp: ?\u00a0, quot: ?" }
        CharRefRx = /&(?:(#{CharEntityTable.keys.join ?|})|#(?:(\d\d\d{0,4})|x([a-f\d][a-f\d][a-f\d]{0,3})));/
        HexColorRx = /^#[a-fA-F0-9]{6}$/
        TextDecorationTable = { 'underline' => :underline, 'line-through' => :strikethrough }
        ThemeKeyToFragmentProperty = {
          'background_color' => :background_color,
          'border_color' => :border_color,
          'border_offset' => :border_offset,
          'border_radius' => :border_radius,
          'border_width' => :border_width,
          'font_color' => :color,
          'font_family' => :font,
          'font_size' => :size,
          'text_decoration_color' => :text_decoration_color,
          'text_decoration_width' => :text_decoration_width,
        }
        #DummyText = ?\u0000

        def initialize options = {}
          @merge_adjacent_text_nodes = options[:merge_adjacent_text_nodes]
          # TODO: add support for character spacing
          if (theme = options[:theme])
            @theme_settings = {
              button: {
                color: theme.button_font_color,
                font: theme.button_font_family,
                size: theme.button_font_size,
                styles: (to_styles theme.button_font_style),
                background_color: (button_bg_color = theme.button_background_color),
                border_width: (button_border_width = theme.button_border_width),
                border_color: button_border_width && (theme.button_border_color || theme.base_border_color),
                border_offset: (button_border_offset = (button_bg_or_border = button_bg_color || button_border_width) && theme.button_border_offset),
                border_radius: button_bg_or_border && theme.button_border_radius,
                align: button_border_offset && :center,
                callback: button_bg_or_border && [TextBackgroundAndBorderRenderer],
              }.compact,
              code: {
                color: theme.literal_font_color,
                font: theme.literal_font_family,
                size: theme.literal_font_size,
                styles: (to_styles theme.literal_font_style),
                background_color: (mono_bg_color = theme.literal_background_color),
                border_width: (mono_border_width = theme.literal_border_width),
                border_color: mono_border_width && (theme.literal_border_color || theme.base_border_color),
                border_offset: (mono_border_offset = (mono_bg_or_border = mono_bg_color || mono_border_width) && theme.literal_border_offset),
                border_radius: mono_bg_or_border && theme.literal_border_radius,
                align: mono_border_offset && :center,
                callback: mono_bg_or_border && [TextBackgroundAndBorderRenderer],
              }.compact,
              key: {
                color: theme.key_font_color,
                font: theme.key_font_family || theme.literal_font_family,
                size: theme.key_font_size,
                styles: (to_styles theme.key_font_style),
                background_color: (key_bg_color = theme.key_background_color),
                border_width: (key_border_width = theme.key_border_width),
                border_color: key_border_width && (theme.key_border_color || theme.base_border_color),
                border_offset: (key_border_offset = (key_bg_or_border = key_bg_color || key_border_width) && theme.key_border_offset),
                border_radius: key_bg_or_border && theme.key_border_radius,
                align: key_border_offset && :center,
                callback: key_bg_or_border && [TextBackgroundAndBorderRenderer],
              }.compact,
              link: {
                color: theme.link_font_color,
                font: theme.link_font_family,
                size: theme.link_font_size,
                styles: (to_styles theme.link_font_style, theme.link_text_decoration),
                text_decoration_color: theme.link_text_decoration_color,
                text_decoration_width: theme.link_text_decoration_width,
              }.compact,
              mark: {
                color: theme.mark_font_color,
                styles: (to_styles theme.mark_font_style),
                background_color: (mark_bg_color = theme.mark_background_color),
                border_offset: (mark_border_offset = mark_bg_color && theme.mark_border_offset),
                align: mark_border_offset && :center,
                callback: mark_bg_color && [TextBackgroundAndBorderRenderer],
              }.compact,
            }
            revise_roles = [].to_set
            theme.each_pair.each_with_object @theme_settings do |(key, val), accum|
              next unless (key = key.to_s).start_with? 'role_'
              role, key = (key.slice 5, key.length).split '_', 2
              if (prop = ThemeKeyToFragmentProperty[key])
                (accum[role] ||= {})[prop] = val
              #elsif key == 'font_kerning'
              #  unless (resolved_val = val == 'none' ? false : (val == 'normal' ? true : nil)).nil?
              #    (accum[role] ||= {})[:kerning] = resolved_val
              #  end
              elsif key == 'font_style' || key == 'text_decoration'
                revise_roles << role
              end
            end
            revise_roles.each_with_object @theme_settings do |role, accum|
              (accum[role] ||= {})[:styles] = to_styles theme[%(role_#{role}_font_style)], theme[%(role_#{role}_text_decoration)]
            end
            @theme_settings['line-through'] = { styles: [:strikethrough].to_set } unless @theme_settings.key? 'line-through'
            @theme_settings['underline'] = { styles: [:underline].to_set } unless @theme_settings.key? 'underline'
            unless @theme_settings.key? 'big'
              if (base_font_size_large = theme.base_font_size_large)
                @theme_settings['big'] = { size: %(#{(base_font_size_large / theme.base_font_size.to_f).round 4}em) }
              else
                @theme_settings['big'] = { size: '1.1667em' }
              end
            end
            unless @theme_settings.key? 'small'
              if (base_font_size_small = theme.base_font_size_small)
                @theme_settings['small'] = { size: %(#{(base_font_size_small / theme.base_font_size.to_f).round 4}em) }
              else
                @theme_settings['small'] = { size: '0.8333em' }
              end
            end
          else
            @theme_settings = {
              button: { font: 'Courier', styles: [:bold].to_set },
              code: { font: 'Courier' },
              key: { font: 'Courier', styles: [:italic].to_set },
              link: { color: '0000FF' },
              mark: { background_color: 'FFFF00', callback: [TextBackgroundAndBorderRenderer] },
              'line-through' => { styles: [:strikethrough].to_set },
              'underline' => { styles: [:underline].to_set },
              'big' => { size: '1.667em' },
              'small' => { size: '0.8333em' },
            }
          end
        end

        def apply parsed, fragments = [], inherited = nil
          previous_fragment_is_text = false
          # NOTE we use each since using inject is slower than a manual loop
          parsed.each do |node|
            case node[:type]
            when :element
              # case 1: non-void element
              if node.key? :pcdata
                # NOTE skip element if it has no children
                if (pcdata = node[:pcdata]).empty?
                  ## NOTE handle an empty anchor element (i.e., <a ...></a>)
                  #if (tag_name = node[:name]) == :a
                  #  seed = clone_fragment inherited, text: DummyText
                  #  fragments << build_fragment(seed, tag_name, node[:attributes])
                  #  previous_fragment_is_text = false
                  #end
                else
                  tag_name = node[:name]
                  attributes = node[:attributes]
                  parent = clone_fragment inherited
                  # NOTE decorate child fragments with inherited properties from this element
                  apply pcdata, fragments, (build_fragment parent, tag_name, attributes)
                  previous_fragment_is_text = false
                end
              # case 2: void element
              else
                case node[:name]
                when :br
                  if @merge_adjacent_text_nodes && previous_fragment_is_text
                    fragments << (clone_fragment inherited, text: %(#{fragments.pop[:text]}#{LF}))
                  else
                    fragments << { text: LF }
                  end
                  previous_fragment_is_text = true
                when :img
                  attributes = node[:attributes]
                  fragment = {
                    image_path: attributes[:src],
                    image_format: attributes[:format],
                    # NOTE: add enclosing square brackets here to avoid errors in parsing
                    text: %([#{attributes[:alt].delete ZeroWidthSpace}]),
                    callback: [InlineImageRenderer],
                    object_id: node.object_id, # used to deduplicate if fragment gets split up
                  }
                  if inherited && (link = inherited[:link])
                    fragment[:link] = link
                  end
                  if (img_w = attributes[:width])
                    fragment[:image_width] = img_w
                  end
                  if (img_fit = attributes[:fit])
                    fragment[:image_fit] = img_fit
                  end
                  fragments << fragment
                  previous_fragment_is_text = false
                end
              end
            when :text
              if @merge_adjacent_text_nodes && previous_fragment_is_text
                fragments << (clone_fragment inherited, text: %(#{fragments.pop[:text]}#{node[:value]}))
              else
                fragments << (clone_fragment inherited, text: node[:value])
              end
              previous_fragment_is_text = true
            when :charref
              if (ref_type = node[:reference_type]) == :name
                text = CharEntityTable[node[:value]]
              elsif ref_type == :decimal
                # FIXME: AFM fonts do not include a thin space glyph; set fallback_fonts to allow glyph to be resolved
                text = [node[:value]].pack 'U1'
              else
                # FIXME: AFM fonts do not include a thin space glyph; set fallback_fonts to allow glyph to be resolved
                text = [(node[:value].to_i 16)].pack 'U1'
              end
              if @merge_adjacent_text_nodes && previous_fragment_is_text
                fragments << (clone_fragment inherited, text: %(#{fragments.pop[:text]}#{text}))
              else
                fragments << (clone_fragment inherited, text: text)
              end
              previous_fragment_is_text = true
            end
          end
          fragments
        end

        def build_fragment fragment, tag_name, attrs = {}
          styles = (fragment[:styles] ||= ::Set.new)
          case tag_name
          when :strong
            styles << :bold
          when :em
            styles << :italic
          when :button, :code, :key, :mark
            update_fragment fragment, @theme_settings[tag_name]
          when :color
            if (rgb = attrs[:rgb])
              case rgb.chr
              when '#'
                fragment[:color] = rgb.slice 1, rgb.length
              when '['
                # treat value as CMYK array (e.g., "[50, 100, 0, 0]")
                fragment[:color] = rgb.slice(1, rgb.length).chomp(']').split(', ').map(&:to_i)
                # ...or we could honor an rgb array too
                #case (vals = rgb.slice(1, rgb.length).chomp(']').split(', ')).size
                #when 4
                #  fragment[:color] = vals.map(&:to_i)
                #when 3
                #  fragment[:color] = vals.map {|e| '%02X' % e.to_i }.join
                #end
              else
                fragment[:color] = rgb
              end
            # QUESTION should we even support r,g,b and c,m,y,k as individual values?
            elsif (r_val = attrs[:r]) && (g_val = attrs[:g]) && (b_val = attrs[:b])
              fragment[:color] = [r_val, g_val, b_val].map {|e| '%02X' % e.to_i }.join
            elsif (c_val = attrs[:c]) && (m_val = attrs[:m]) && (y_val = attrs[:y]) && (k_val = attrs[:k])
              fragment[:color] = [c_val.to_i, m_val.to_i, y_val.to_i, k_val.to_i]
            end
          when :font
            if (value = attrs[:name])
              fragment[:font] = value
            end
            if (value = attrs[:size])
              # FIXME: can we make this comparison more robust / accurate?
              if (f_value = value.to_f).to_s == value || value.to_i.to_s == value
                fragment[:size] = f_value
              elsif value != '1em'
                fragment[:size] = value
              end
            end
            # NOTE width is used for font-based icons
            if (value = attrs[:width])
              fragment[:width] = value
              fragment[:align] = :center
              fragment[:callback] = (fragment[:callback] || []) | [InlineTextAligner]
            end
            #if (value = attrs[:character_spacing])
            #  fragment[:character_spacing] = value.to_f
            #end
          when :a
            visible = true
            # a element can have no attributes, so short-circuit if that's the case
            unless attrs.empty?
              # NOTE href, anchor, and name are mutually exclusive; nesting is not supported
              if (value = attrs[:anchor])
                fragment[:anchor] = value
              elsif (value = attrs[:href])
                fragment[:link] = (value.include? ';') ? (value.gsub CharRefRx do
                  $1 ? CharEntityTable[$1.to_sym] : [$2 ? $2.to_i : ($3.to_i 16)].pack('U1')
                end) : value
              elsif (value = attrs[:id] || attrs[:name])
                # NOTE text is null character, which is used as placeholder text so Prawn doesn't drop fragment
                fragment = { name: value, callback: [InlineDestinationMarker] }
                if (type = attrs[:type])
                  fragment[:type] = type.to_sym
                end
                visible = nil
              end
            end
            update_fragment fragment, @theme_settings[:link] if visible
          when :sub
            styles << :subscript
          when :sup
            styles << :superscript
          when :del
            styles << :strikethrough
          when :span
            # NOTE spaces in style value are superfluous for our purpose; split drops record after trailing ;
            attrs[:style].tr(' ', '').split(';').each do |style|
              pname, pvalue = style.split ':', 2
              # TODO: text-transform
              case pname
              when 'color'
                # TODO: check whether the value is a valid hex color?
                case pvalue.length
                when 6
                  fragment[:color] = pvalue
                when 7
                  fragment[:color] = pvalue.slice 1, 6 if pvalue.start_with? '#'
                end
                # QUESTION should we support the 3 character form?
                #when 3
                #  fragment[:color] = pvalue.each_char.map {|c| c * 2 }.join
                #when 4
                #  fragment[:color] = pvalue.slice(1, 3).each_char.map {|c| c * 2 }.join if pvalue.start_with?('#')
              when 'font-weight'
                styles << :bold if pvalue == 'bold'
              when 'font-style'
                styles << :italic if pvalue == 'italic'
              when 'align', 'text-align'
                fragment[:align] = pvalue.to_sym
                fragment[:callback] = (fragment[:callback] || []) | [InlineTextAligner]
              when 'width'
                # NOTE implicitly activates inline-block behavior
                fragment[:width] = pvalue
              when 'background-color' # background-color needed to support syntax highlighters
                if (pvalue.start_with? '#') && (HexColorRx.match? pvalue)
                  fragment[:background_color] = pvalue.slice 1, pvalue.length
                  fragment[:callback] = [TextBackgroundAndBorderRenderer] | (fragment[:callback] || [])
                end
              end
            end if attrs.key? :style
          end
          # TODO: we could limit to select tags, but doesn't seem to really affect performance
          attrs[:class].split.each do |class_name|
            next unless @theme_settings.key? class_name
            update_fragment fragment, @theme_settings[class_name]
            if fragment[:background_color] || (fragment[:border_color] && fragment[:border_width])
              fragment[:callback] = [TextBackgroundAndBorderRenderer] | (fragment[:callback] || [])
              fragment[:align] = :center if fragment[:border_offset]
            end
          end if attrs.key? :class
          fragment.delete :styles if styles.empty?
          fragment[:callback] = (fragment[:callback] || []) | [InlineTextAligner] if fragment.key? :align
          fragment
        end

        def clone_fragment fragment, append = nil
          if fragment
            fragment = fragment.dup
            fragment[:styles] = fragment[:styles].dup if fragment.key? :styles
            fragment[:callback] = fragment[:callback].dup if fragment.key? :callback
          else
            fragment = {}
          end
          fragment.update append if append
          fragment
        end

        def to_styles font_style, text_decoration = nil
          case font_style
          when 'bold'
            styles = [:bold].to_set
          when 'italic'
            styles = [:italic].to_set
          when 'bold_italic'
            styles = [:bold, :italic].to_set
          end
          if (style = TextDecorationTable[text_decoration])
            styles ? (styles << style) : [style].to_set
          else
            styles
          end
        end

        def update_fragment fragment, props
          fragment.update props do |k, oval, nval|
            case k
            when :styles
              nval ? (oval.merge nval) : oval.clear
            when :callback
              oval | nval
            else
              nval
            end
          end
        end
      end
    end
  end
end
