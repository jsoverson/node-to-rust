# encoding: utf-8
#
# interface.rb: Prawn extension module and logic.
#
# Copyright October 2016, Jesse Doyle. All rights reserved.
#
# This is free software. Please see the LICENSE and COPYING files for details.

module Prawn
  # Easy icon font usage within Prawn. Currently
  # supported icon fonts include: FontAwesome,
  # Zurb Foundicons and PaymentFont.
  #
  # = Icon Keys
  #
  # Icon keys must be supplied to most +Prawn::Icon+
  # methods. Keys map directly to a unicode character
  # within the font that produces a given icon. As a
  # rule, included icon keys should match the keys from
  # the font provider. The icon key mapping is specified
  # in the font's +legend_file+, which is a +YAML+ file
  # located in {Prawn::Icon.configuration.font_directory}/font/font.yml.
  #
  # Prawn::Icon::
  #   Houses the methods and interfaces necessary for
  #   rendering icons to the Prawn::Document.
  #
  # Prawn::Icon::FontData::
  #   Used to store various information about an icon font,
  #   including the key-to-unicode mapping information.
  #   Also houses methods to cache and lazily load the
  #   requested font data on a document basis.
  #
  # Prawn::Icon::Parser::
  #   Used to initially parse icons that are used with the
  #   inline_format: true option. The input string is parsed
  #   once for <icon></icon> tags, then the output is provided
  #   to Prawn's internal formatted text parser.
  #
  class Icon
    # @deprecated Use {Prawn::Icon.configuration.font_directory} instead
    FONTDIR = Icon::Base::FONTDIR

    module Interface
      # Set up and draw an icon on this document. This
      # method operates much like +Prawn::Text::Box+.
      #
      # == Parameters:
      # key::
      #   Contains the key to a particular icon within
      #   a font family. If :inline_format is true,
      #   then key may contain formatted text marked
      #   with <icon></icon> tags and any tag supported
      #   by Prawn's parser.
      #
      # opts::
      #   A hash of options that may be supplied to
      #   the underlying +text+ method call.
      #
      # == Examples:
      #   pdf.icon 'fas-beer'
      #   pdf.icon '<icon color="0099FF">fas-user-circle</icon>',
      #   inline_format: true
      #
      def icon(key, opts = {})
        key = translate_key(key)
        make_icon(key, opts).tap { |i| i && i.render }
      end

      # Initialize a new icon object.
      #
      # == Parameters:
      # key::
      #   Contains the key to a particular icon within
      #   a font family. If :inline_format is true,
      #   then key may contain formatted text marked
      #   with <icon></icon> tags and any tag supported
      #   by Prawn's parser.
      #
      # opts::
      #   A hash of options that may be supplied to
      #   the underlying text method call.
      #
      def make_icon(key, opts = {})
        key = translate_key(key)
        if opts.fetch(:inline_format, false)
          inline_icon(key, opts)
        else
          Icon.new(key, self, opts)
        end
      end

      # Render formatted icon content to the document from
      # a string containing icons. Content will correctly
      # transition to a new page when necessary.
      #
      # == Parameters:
      # text::
      #   Input text to be parsed initially for <icon>
      #   tags, then passed to Prawn's formatted text
      #   parser.
      #
      # opts::
      #   A hash of options that may be supplied to the
      #   underlying text call.
      #
      def inline_icon(text, opts = {})
        parsed = Icon::Parser.format(self, text)
        content = Text::Formatted::Parser.format(parsed)
        formatted_text(content, opts)
      end

      # Initialize a formatted icon box from an icon-conatining
      # string. Content is not directly rendered to the document,
      # instead a +Prawn::Text::Formatted::Box+ instance is returned
      # that responds to the +render+ method.
      #
      # == Parameters:
      # text::
      #   Input text to be parsed initially for <icon>
      #   tags, then passed to Prawn's formatted text
      #   parser.
      #
      # opts::
      #   A hash of options that may be supplied to the
      #   underlying text call.
      #
      def formatted_icon_box(text, opts = {})
        parsed = Icon::Parser.format(self, text)
        content = Text::Formatted::Parser.format(parsed)
        position = opts.fetch(:at) do
          [
            opts.fetch(:x) { bounds.left },
            opts.fetch(:y) { cursor }
          ]
        end
        box_options = opts.merge(
          inline_format: true,
          document: self,
          at: position
        )
        icon_box(content, box_options)
      end

      # Initialize a new Prawn::Icon, but don't render
      # the icon to a document. Intended to be used as
      # an entry of a data array when combined with
      # Prawn::Table.
      #
      # == Parameters:
      # key::
      #   Contains the key to a particular icon within
      #   a font family. The key may contain a string
      #   with format tags if +inline_format: true+ in
      #   the +opts+ hash.
      #
      # opts::
      #   A hash of options that may be supplied to the
      #   underlying text call.
      #
      # == Returns:
      #   A Hash containing +font+ and +content+ keys
      #   that match the data necessary for the
      #   specified icon.
      #
      #   eg. { font: 'fas', content: "\uf2b9" }
      #
      #   Note that the +font+ key will not be set
      #   if +inline_format: true+.
      #
      # == Examples:
      #   require 'prawn/table'
      #
      #   data = [
      #     # Explicit brackets must be used here
      #     [pdf.table_icon('fas-coffee'), 'Cell 1'],
      #     ['Cell 2', 'Cell 3']
      #   ]
      #
      #   pdf.table(data) => (2 x 2 table)
      #
      def table_icon(key, opts = {})
        key = translate_key(key)
        if opts[:inline_format]
          content = Icon::Parser.format(self, key)
          opts.merge(content: content)
        else
          make_icon(key, opts).format_hash
        end
      end

      private

      def translate_key(key)
        Compatibility.new(key: key).translate
      end

      def icon_box(content, opts = {}) # :nodoc:
        Text::Formatted::Box.new(content, opts).tap do |box|
          box.render(dry_run: true)
          self.y -= box.height
          unless opts.fetch(:final_gap, true)
            self.y -= box.line_gap + box.leading
          end
        end
      end
    end

    attr_reader :set, :unicode

    def initialize(key, document, opts = {})
      @pdf     = document
      @set     = opts.fetch(:set) { FontData.specifier_from_key(key) }
      @data    = FontData.load(document, @set)
      @key     = strip_specifier_from_key(key)
      @unicode = @data.unicode(@key)
      @options = opts
    end

    def format_hash
      base = { font: @set.to_s, content: @unicode }
      opts = @options.dup
      # Prawn::Table renames :color to :text_color
      opts[:text_color] = opts.delete(:color)
      base.merge(opts)
    end

    def render
      @pdf.font(@data.path) do
        @pdf.text @unicode, @options
      end
    end

    private

    def strip_specifier_from_key(key) # :nodoc:
      reg = Regexp.new "#{@data.specifier}-"
      key.sub(reg, '') # Only one specifier
    end
  end
end
