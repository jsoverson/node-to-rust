# frozen_string_literal: true

module Asciidoctor
  module PDF
    module Sanitizer
      XMLSpecialChars = {
        '&lt;' => ?<,
        '&gt;' => ?>,
        '&amp;' => ?&,
      }
      XMLSpecialCharsRx = /(?:#{XMLSpecialChars.keys.join ?|})/
      InverseXMLSpecialChars = XMLSpecialChars.invert
      InverseXMLSpecialCharsRx = /[#{InverseXMLSpecialChars.keys.join}]/
      (BuiltInNamedEntities = {
        'amp' => ?&,
        'apos' => ?',
        'gt' => ?>,
        'lt' => ?<,
        'nbsp' => ' ',
        'quot' => ?",
      }).default = ??
      SanitizeXMLRx = /<[^>]+>/
      CharRefRx = /&(?:([a-z][a-z]+\d{0,2})|#(?:(\d\d\d{0,4})|x([a-f\d][a-f\d][a-f\d]{0,3})));/

      # Strip leading, trailing and repeating whitespace, remove XML tags and
      # resolve all entities in the specified string.
      #
      # FIXME move to a module so we can mix it in elsewhere
      # FIXME add option to control escaping entities, or a filter mechanism in general
      def sanitize string
        string = string.gsub SanitizeXMLRx, '' if string.include? '<'
        string = string.gsub(CharRefRx) { $1 ? BuiltInNamedEntities[$1] : ([$2 ? $2.to_i : ($3.to_i 16)].pack 'U1') } if string.include? '&'
        string.strip.tr_s ' ', ' '
      end

      def escape_xml string
        string.gsub InverseXMLSpecialCharsRx, InverseXMLSpecialChars
      end

      def encode_quotes string
        (string.include? ?") ? (string.gsub ?", '&quot;') : string
      end
    end
  end
end
