# frozen_string_literal: true

require 'safe_yaml/load'
require 'ostruct'
require_relative 'measurements'

module Asciidoctor
  module PDF
    class ThemeLoader
      include ::Asciidoctor::PDF::Measurements
      include ::Asciidoctor::Logging

      DataDir = ::File.absolute_path %(#{__dir__}/../../../data)
      ThemesDir = ::File.join DataDir, 'themes'
      FontsDir = ::File.join DataDir, 'fonts'
      BaseThemePath = ::File.join ThemesDir, 'base-theme.yml'

      VariableRx = /\$([a-z0-9_-]+)/
      LoneVariableRx = /^\$([a-z0-9_-]+)$/
      HexColorEntryRx = /^(?<k> *\p{Graph}+): +(?!null$)(?<q>["']?)(?<h>#)?(?<v>[a-fA-F0-9]{3,6})\k<q> *(?:#.*)?$/
      MultiplyDivideOpRx = /(-?\d+(?:\.\d+)?) +([*\/]) +(-?\d+(?:\.\d+)?)/
      AddSubtractOpRx = /(-?\d+(?:\.\d+)?) +([+\-]) +(-?\d+(?:\.\d+)?)/
      PrecisionFuncRx = /^(round|floor|ceil)\(/

      # TODO: implement white? & black? methods
      module ColorValue; end

      class HexColorValue < String
        include ColorValue
      end

      # A marker module for a normalized CMYK array
      # Prevents normalizing CMYK value more than once
      module CMYKColorValue
        include ColorValue
        def to_s
          %([#{join ', '}])
        end
      end

      def self.resolve_theme_file theme_name = nil, theme_dir = nil
        # NOTE if .yml extension is given, assume it's a path (don't append -theme.yml)
        if theme_name && (theme_name.end_with? '.yml')
          # FIXME: restrict to jail!
          if theme_dir
            theme_path = ::File.absolute_path theme_name, (theme_dir = ::File.expand_path theme_dir)
          else
            theme_path = ::File.expand_path theme_name
            theme_dir = ::File.dirname theme_path
          end
        else
          theme_dir = theme_dir ? (::File.expand_path theme_dir) : ThemesDir
          theme_path = ::File.absolute_path ::File.join theme_dir, %(#{theme_name || 'default'}-theme.yml)
        end
        [theme_path, theme_dir]
      end

      def self.resolve_theme_asset asset_path, theme_dir = nil
        ::File.absolute_path asset_path, (theme_dir || ThemesDir)
      end

      # NOTE base theme is loaded "as is" (no post-processing)
      def self.load_base_theme
        (::OpenStruct.new ::SafeYAML.load_file BaseThemePath).tap {|theme| theme.__dir__ = ThemesDir }
      end

      def self.load_theme theme_name = nil, theme_dir = nil
        theme_path, theme_dir = resolve_theme_file theme_name, theme_dir
        if theme_path == BaseThemePath
          load_base_theme
        else
          theme_data = load_file theme_path, nil, theme_dir
          unless (::File.dirname theme_path) == ThemesDir
            theme_data.base_align ||= 'left'
            theme_data.base_line_height ||= 1
            theme_data.base_font_color ||= '000000'
            theme_data.code_font_family ||= (theme_data.literal_font_family || 'Courier')
            theme_data.conum_font_family ||= (theme_data.literal_font_family || 'Courier')
            if (heading_font_family = theme_data.heading_font_family)
              theme_data.abstract_title_font_family ||= heading_font_family
              theme_data.sidebar_title_font_family ||= heading_font_family
            end
          end
          theme_data.__dir__ = theme_dir
          theme_data
        end
      end

      def self.load_file filename, theme_data = nil, theme_dir = nil
        data = ::File.read filename, mode: 'r:UTF-8', newline: :universal
        data = data.each_line.map {|line|
          line.sub(HexColorEntryRx) { %(#{(m = $~)[:k]}: #{m[:h] || (m[:k].end_with? 'color') ? "'#{m[:v]}'" : m[:v]}) }
        }.join unless (::File.dirname filename) == ThemesDir
        yaml_data = ::SafeYAML.load data, filename
        if ::Hash === yaml_data && (yaml_data.key? 'extends')
          if (extends = yaml_data.delete 'extends')
            (Array extends).each do |extend_path|
              if extend_path == 'base'
                theme_data = theme_data ? (::OpenStruct.new theme_data.to_h.merge load_base_theme.to_h) : load_base_theme
                next
              elsif extend_path == 'default' || extend_path == 'default-with-fallback-font'
                extend_path, extend_theme_dir = resolve_theme_file extend_path, ThemesDir
              elsif extend_path.start_with? './'
                extend_path, extend_theme_dir = resolve_theme_file extend_path, (::File.dirname filename)
              else
                extend_path, extend_theme_dir = resolve_theme_file extend_path, theme_dir
              end
              theme_data = load_file extend_path, theme_data, extend_theme_dir
            end
          end
        else
          theme_data ||= ((::File.dirname filename) == ThemesDir ? nil : load_base_theme)
        end
        new.load yaml_data, theme_data
      end

      def load hash, theme_data = nil
        ::Hash === hash ? hash.reduce(theme_data || ::OpenStruct.new) {|data, (key, val)| process_entry key, val, data, true } : (theme_data || ::OpenStruct.new)
      end

      private

      def process_entry key, val, data, normalize_key = false
        key = key.tr '-', '_' if normalize_key && (key.include? '-')
        if key == 'font'
          val.each do |subkey, subval|
            process_entry %(#{key}_#{subkey}), subval, data if subkey == 'catalog' || subkey == 'fallbacks'
          end if ::Hash === val
        elsif key == 'font_catalog'
          data[key] = ::Hash === val ? (val.reduce (val.delete 'merge') ? data[key] || {} : {} do |accum, (name, styles)| # rubocop:disable Style/EachWithObject
            styles = %w(normal bold italic bold_italic).map {|style| [style, styles] }.to_h if ::String === styles
            accum[name] = styles.reduce({}) do |subaccum, (style, path)| # rubocop:disable Style/EachWithObject
              if (path.start_with? 'GEM_FONTS_DIR') && (sep = path[13])
                path = %(#{FontsDir}#{sep}#{path.slice 14, path.length})
              end
              subaccum[style == 'regular' ? 'normal' : style] = expand_vars path, data
              subaccum
            end if ::Hash === styles
            accum
          end) : {}
        elsif key == 'font_fallbacks'
          data[key] = ::Array === val ? val.map {|name| expand_vars name.to_s, data } : []
        elsif key.start_with? 'admonition_icon_'
          data[key] = val ? val.map {|(key2, val2)|
            key2 = key2.tr '-', '_' if key2.include? '-'
            [key2.to_sym, (key2.end_with? '_color') ? (to_color evaluate val2, data) : (evaluate val2, data)]
          }.to_h : {}
        elsif ::Hash === val
          val.each do |subkey, subval|
            process_entry %(#{key}_#{key == 'role' || !(subkey.include? '-') ? subkey : (subkey.tr '-', '_')}), subval, data
          end
        elsif key.end_with? '_color'
          # QUESTION do we really need to evaluate_math in this case?
          data[key] = to_color evaluate val, data
        elsif key.end_with? '_content'
          data[key] = (expand_vars val.to_s, data).to_s
        else
          data[key] = evaluate val, data
        end
        data
      end

      def evaluate expr, vars
        case expr
        when ::String
          evaluate_math expand_vars expr, vars
        when ::Array
          expr.map {|e| evaluate e, vars }
        else
          expr
        end
      end

      # NOTE we assume expr is a String
      def expand_vars expr, vars
        if (idx = (expr.index '$'))
          if idx == 0 && expr =~ LoneVariableRx
            if (key = $1).include? '-'
              key = key.tr '-', '_'
            end
            if vars.respond_to? key
              vars[key]
            else
              logger.warn %(unknown variable reference in PDF theme: $#{$1})
              expr
            end
          else
            expr.gsub VariableRx do
              if (key = $1).include? '-'
                key = key.tr '-', '_'
              end
              if vars.respond_to? key
                vars[key]
              else
                logger.warn %(unknown variable reference in PDF theme: $#{$1})
                $&
              end
            end
          end
        else
          expr
        end
      end

      def evaluate_math expr
        return expr if !(::String === expr) || ColorValue === expr
        # resolve measurement values (e.g., 0.5in => 36)
        # QUESTION should we round the value? perhaps leave that to the precision functions
        # NOTE leave % as a string; handled by converter for now
        original, expr = expr, (resolve_measurement_values expr)
        loop do
          if (expr.count '*/') > 0
            result = expr.gsub(MultiplyDivideOpRx) { $1.to_f.send $2.to_sym, $3.to_f }
            unchanged = (result == expr)
            expr = result
            break if unchanged
          else
            break
          end
        end
        loop do
          if (expr.count '+-') > 0
            result = expr.gsub(AddSubtractOpRx) { $1.to_f.send $2.to_sym, $3.to_f }
            unchanged = (result == expr)
            expr = result
            break if unchanged
          else
            break
          end
        end
        if (expr.end_with? ')') && expr =~ PrecisionFuncRx
          op = $1
          offset = op.length + 1
          expr = expr[offset...-1].to_f.send op.to_sym
        end
        if expr == original
          original
        else
          (int_val = expr.to_i) == (flt_val = expr.to_f) ? int_val : flt_val
        end
      end

      def to_color value
        case value
        when ColorValue
          # already converted
          return value
        when ::Array
          case value.length
          # CMYK value
          when 4
            value = value.map do |e|
              if ::Numeric === e
                e *= 100.0 unless e > 1
              else
                e = e.to_s.chomp('%').to_f
              end
              e == (int_e = e.to_i) ? int_e : e
            end
            case value
            when [0, 0, 0, 0]
              return HexColorValue.new 'FFFFFF'
            when [100, 100, 100, 100]
              return HexColorValue.new '000000'
            else
              value.extend CMYKColorValue
              return value
            end
          # RGB value
          when 3
            return HexColorValue.new value.map {|e| '%02X' % e }.join
          # Nonsense array value; flatten to string
          else
            value = value.join
          end
        when ::String
          if value == 'transparent'
            # FIXME: should we have a TransparentColorValue class?
            return HexColorValue.new value
          elsif value.length == 6
            return HexColorValue.new value.upcase
          end
        when ::NilClass
          return nil
        else
          # Unknown type (usually Integer); coerce to String
          if (value = value.to_s).length == 6
            return HexColorValue.new value.upcase
          end
        end
        case value.length
        when 6
          resolved_value = value
        when 3
          # expand hex shorthand (e.g., f00 -> ff0000)
          resolved_value = value.each_char.map {|c| c * 2 }.join
        else
          # truncate or pad with leading zeros (e.g., ff -> 0000ff)
          resolved_value = (value.slice 0, 6).rjust 6, '0'
        end
        HexColorValue.new resolved_value.upcase
      end
    end
  end
end
