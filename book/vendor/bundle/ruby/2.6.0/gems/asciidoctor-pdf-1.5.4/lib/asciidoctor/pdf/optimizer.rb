# frozen_string_literal: true

require 'pathname'
require 'rghost'
require 'tmpdir'

module Asciidoctor
  module PDF
    class Optimizer
      (QUALITY_NAMES = {
        'default' => :default,
        'screen' => :screen,
        'ebook' => :ebook,
        'printer' => :printer,
        'prepress' => :prepress,
      }).default = :default

      def initialize quality = 'default', compatibility_level = '1.4'
        @quality = QUALITY_NAMES[quality]
        @compatibility_level = compatibility_level
      end

      def generate_file target
        ::Dir::Tmpname.create ['asciidoctor-pdf-', '.pdf'] do |tmpfile|
          filename = Pathname.new target
          filename_o = Pathname.new tmpfile
          pdfmark = filename.sub_ext '.pdfmark'
          inputs = pdfmark.file? ? [target, pdfmark.to_s] : target
          (::RGhost::Convert.new inputs).to :pdf,
              filename: filename_o.to_s,
              quality: @quality,
              d: { Printed: false, CannotEmbedFontPolicy: '/Warning', CompatibilityLevel: @compatibility_level }
          begin
            filename_o.rename target
          rescue ::Errno::EXDEV
            filename.binwrite filename_o.binread
            filename_o.unlink
          end
        end
        nil
      end
    end
  end
end
