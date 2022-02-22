# frozen_string_literal: true

module Asciidoctor
  module Image
    DataUriRx = /^data:image\/(?<fmt>png|jpe?g|gif|pdf|bmp|tiff|svg\+xml);base64,(?<data>.*)$/
    FormatAliases = { 'jpg' => 'jpeg', 'svg+xml' => 'svg' }

    class << self
      def format image_path, attributes = nil
        (attributes && attributes['format']) || ((ext = ::File.extname image_path).downcase.slice 1, ext.length)
      end

      def target_and_format image_path, attributes = nil
        if (image_path.start_with? 'data:') && (m = DataUriRx.match image_path)
          [(m[:data].extend ::Base64), (FormatAliases.fetch m[:fmt], m[:fmt])]
        else
          [image_path, (attributes && attributes['format']) || ((ext = ::File.extname image_path).downcase.slice 1, ext.length)]
        end
      end
    end

    def format
      (attr 'format', nil, false) || ((ext = ::File.extname(inline? ? target : (attr 'target'))).downcase.slice 1, ext.length)
    end

    def target_and_format
      image_path = inline? ? target : (attr 'target')
      if (image_path.start_with? 'data:') && (m = DataUriRx.match image_path)
        [(m[:data].extend ::Base64), (FormatAliases.fetch m[:fmt], m[:fmt])]
      else
        [image_path, (attr 'format', nil, false) || ((ext = ::File.extname image_path).downcase.slice 1, ext.length)]
      end
    end
  end
end
