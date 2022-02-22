# frozen_string_literal: true

require_relative 'formatted_text'
require_relative 'index_catalog'
require_relative 'pdfmark'
require_relative 'roman_numeral'

autoload :StringIO, 'stringio'
autoload :Tempfile, 'tempfile'

module Asciidoctor
  module PDF
    class Converter < ::Prawn::Document
      include ::Asciidoctor::Converter
      include ::Asciidoctor::Logging
      include ::Asciidoctor::Writer
      include ::Asciidoctor::Prawn::Extensions

      register_for 'pdf'

      attr_reader :allow_uri_read

      attr_reader :cache_uri

      attr_reader :theme

      attr_reader :text_decoration_width

      # NOTE require_library doesn't support require_relative and we don't modify the load path for this gem
      CodeRayRequirePath = ::File.join __dir__, 'ext/prawn/coderay_encoder'
      RougeRequirePath = ::File.join __dir__, 'ext/rouge'
      PygmentsRequirePath = ::File.join __dir__, 'ext/pygments'
      OptimizerRequirePath = ::File.join __dir__, 'optimizer'

      AsciidoctorVersion = ::Gem::Version.new ::Asciidoctor::VERSION
      AdmonitionIcons = {
        caution: { name: 'fas-fire', stroke_color: 'BF3400', size: 24 },
        important: { name: 'fas-exclamation-circle', stroke_color: 'BF0000', size: 24 },
        note: { name: 'fas-info-circle', stroke_color: '19407C', size: 24 },
        tip: { name: 'far-lightbulb', stroke_color: '111111', size: 24 },
        warning: { name: 'fas-exclamation-triangle', stroke_color: 'BF6900', size: 24 },
      }
      TextAlignmentNames = %w(justify left center right)
      TextAlignmentRoles = %w(text-justify text-left text-center text-right)
      TextDecorationStyleTable = { 'underline' => :underline, 'line-through' => :strikethrough }
      FontKerningTable = { 'normal' => true, 'none' => false }
      BlockAlignmentNames = %w(left center right)
      AlignmentTable = { '<' => :left, '=' => :center, '>' => :right }
      ColumnPositions = [:left, :center, :right]
      PageLayouts = [:portrait, :landscape]
      (PageModes = {
        'fullscreen' => [:FullScreen, :UseOutlines],
        'fullscreen none' => [:FullScreen, :UseNone],
        'fullscreen outline' => [:FullScreen, :UseOutlines],
        'fullscreen thumbs' => [:FullScreen, :UseThumbs],
        'none' => :UseNone,
        'outline' => :UseOutlines,
        'thumbs' => :UseThumbs,
      }).default = :UseOutlines
      PageSides = [:recto, :verso]
      (PDFVersions = { '1.3' => 1.3, '1.4' => 1.4, '1.5' => 1.5, '1.6' => 1.6, '1.7' => 1.7 }).default = 1.4
      AuthorAttributeNames = %w(author authorinitials firstname middlename lastname email)
      LF = ?\n
      DoubleLF = LF * 2
      TAB = ?\t
      InnerIndent = LF + ' '
      # a no-break space is used to replace a leading space to prevent Prawn from trimming indentation
      # a leading zero-width space can't be used as it gets dropped when calculating the line width
      GuardedIndent = ?\u00a0
      GuardedInnerIndent = LF + GuardedIndent
      TabRx = /\t/
      TabIndentRx = /^\t+/
      NoBreakSpace = ?\u00a0
      ZeroWidthSpace = ?\u200b
      DummyText = ?\u0000
      DotLeaderTextDefault = '. '
      EmDash = ?\u2014
      RightPointer = ?\u25ba
      LowercaseGreekA = ?\u03b1
      Bullets = {
        disc: ?\u2022,
        circle: ?\u25e6,
        square: ?\u25aa,
        none: '',
      }
      # NOTE Default theme font uses ballot boxes from FontAwesome
      BallotBox = {
        checked: ?\u2611,
        unchecked: ?\u2610,
      }
      ConumSets = {
        'circled' => (?\u2460..?\u2473).to_a,
        'filled' => (?\u2776..?\u277f).to_a + (?\u24eb..?\u24f4).to_a,
      }
      SimpleAttributeRefRx = /(?<!\\)\{\w+(?:-\w+)*\}/
      MeasurementRxt = '\\d+(?:\\.\\d+)?(?:in|cm|mm|p[txc])?'
      MeasurementPartsRx = /^(\d+(?:\.\d+)?)(in|mm|cm|p[txc])?$/
      PageSizeRx = /^(?:\[(#{MeasurementRxt}), ?(#{MeasurementRxt})\]|(#{MeasurementRxt})(?: x |x)(#{MeasurementRxt})|\S+)$/
      CalloutExtractRx = /(?:(?:\/\/|#|--|;;) ?)?(\\)?<!?(|--)(\d+|\.)\2> ?(?=(?:\\?<!?\2(?:\d+|\.)\2>)*$)/
      ImageAttributeValueRx = /^image:{1,2}(.*?)\[(.*?)\]$/
      StopPunctRx = /[.!?;:]$/
      UriBreakCharsRx = /(?:\/|\?|&amp;|#)(?!$)/
      UriBreakCharRepl = %(\\&#{ZeroWidthSpace})
      UriSchemeBoundaryRx = /(?<=:\/\/)/
      LineScanRx = /\n|.+/
      BlankLineRx = /\n{2,}/
      CjkLineBreakRx = /(?=[\u3000\u30a0-\u30ff\u3040-\u309f\p{Han}\uff00-\uffef])/
      WhitespaceChars = ' ' + TAB + LF
      ValueSeparatorRx = /;|,/
      HexColorRx = /^#[a-fA-F0-9]{6}$/
      VimeoThumbnailRx = /<thumbnail_url>(.*?)<\/thumbnail_url>/
      SourceHighlighters = %w(coderay pygments rouge).to_set
      ViewportWidth = ::Module.new
      (TitleStyles = {
        'toc' => [:numbered_title],
        'basic' => [:title],
      }).default = [:numbered_title, formal: true]

      def initialize backend, opts
        super
        basebackend 'html'
        filetype 'pdf'
        htmlsyntax 'html'
        outfilesuffix '.pdf'
        if (doc = opts[:document])
          # NOTE enabling data-uri forces Asciidoctor Diagram to produce absolute image paths
          doc.attributes['data-uri'] = ((doc.instance_variable_get :@attribute_overrides) || {})['data-uri'] = ''
        end
        @capabilities = {
          special_sectnums: AsciidoctorVersion >= (::Gem::Version.new '1.5.7'),
          syntax_highlighter: AsciidoctorVersion >= (::Gem::Version.new '2.0.0'),
        }
        @initial_instance_variables = [:@initial_instance_variables] + instance_variables
      end

      def convert node, name = nil, _opts = {}
        method_name = %(convert_#{name ||= node.node_name})
        if respond_to? method_name
          result = send method_name, node
        else
          # TODO: delegate to convert_method_missing
          logger.warn %(conversion missing in backend #{@backend} for #{name}) unless scratch?
        end
        # NOTE: inline nodes generate pseudo-HTML strings; the remainder write directly to PDF object
        ::Asciidoctor::Inline === node ? result : self
      end

      def traverse node, opts = {}
        # NOTE converter instance in scratch document gets duplicated; must be rewired to this one
        if self == (prev_converter = node.document.converter)
          prev_converter = nil
        else
          node.document.instance_variable_set :@converter, self
        end
        if node.blocks?
          node.content
        elsif node.content_model != :compound && (string = node.content)
          # TODO: this content could be cached on repeat invocations!
          layout_prose string, (opts.merge hyphenate: true)
        end
        node.document.instance_variable_set :@converter, prev_converter if prev_converter
      end

      def convert_document doc
        init_pdf doc
        # set default value for pagenums if not otherwise set
        doc.attributes['pagenums'] = '' unless (doc.attribute_locked? 'pagenums') || ((doc.instance_variable_get :@attributes_modified).include? 'pagenums')
        if (idx_sect = doc.sections.find {|candidate| candidate.sectname == 'index' }) && idx_sect.numbered
          idx_sect.numbered = false
        end unless @capabilities[:special_sectnums]
        #assign_missing_section_ids doc

        # promote anonymous preface (defined using preamble block) to preface section
        # FIXME: this should be done in core
        if doc.doctype == 'book' && (blk0 = doc.blocks[0]) && blk0.context == :preamble && blk0.title? &&
            !blk0.title.nil_or_empty? && blk0.blocks[0].style != 'abstract' && (blk1 = doc.blocks[1]) && blk1.context == :section
          preface = Section.new doc, blk1.level, false, attributes: { 1 => 'preface', 'style' => 'preface' }
          preface.special = true
          preface.sectname = 'preface'
          preface.title = blk0.instance_variable_get :@title
          # QUESTION should ID be generated from raw or converted title? core is not clear about this
          preface.id = preface.generate_id
          preface.blocks.replace blk0.blocks.map {|b| (b.parent = preface) && b }
          doc.blocks[0] = preface
          blk0 = blk1 = preface = nil # rubocop:disable Lint/UselessAssignment
        end

        on_page_create(&(method :init_page))

        marked_page_number = page_number
        # NOTE: a new page will already be started (page_number = 2) if the front cover image is a PDF
        layout_cover_page doc, :front
        has_front_cover = page_number > marked_page_number

        if (use_title_page = doc.doctype == 'book' || (doc.attr? 'title-page'))
          layout_title_page doc
          has_title_page = page_number == (has_front_cover ? 2 : 1)
        end

        @page_margin_by_side[:cover] = @page_margin_by_side[:recto] if @media == 'prepress' && page_number == 0

        # NOTE: font must be set before content is written to the main or scratch document
        start_new_page unless page.empty?
        font @theme.base_font_family, size: @root_font_size, style: (@theme.base_font_style || :normal).to_sym

        unless use_title_page
          body_start_page_number = page_number
          theme_font :heading, level: 1 do
            layout_heading doc.doctitle, align: (@theme.heading_h1_align || :center).to_sym, level: 1
          end if doc.header? && !doc.notitle
        end

        num_front_matter_pages = toc_page_nums = toc_num_levels = nil

        indent_section do
          toc_num_levels = (doc.attr 'toclevels', 2).to_i
          if (insert_toc = (doc.attr? 'toc') && !(doc.attr? 'toc-placement', 'macro') && doc.sections?)
            start_new_page if @ppbook && verso_page?
            allocate_toc doc, toc_num_levels, @y, use_title_page
          else
            @toc_extent = nil
          end

          start_new_page if @ppbook && verso_page?

          if use_title_page
            zero_page_offset = has_front_cover ? 1 : 0
            first_page_offset = has_title_page ? zero_page_offset.next : zero_page_offset
            body_offset = (body_start_page_number = page_number) - 1
            if ::Integer === (running_content_start_at = @theme.running_content_start_at || 'body')
              running_content_body_offset = body_offset + [running_content_start_at.pred, 1].max
              running_content_start_at = 'body'
            else
              running_content_body_offset = body_offset
              running_content_start_at = 'toc' if running_content_start_at == 'title' && !has_title_page
              running_content_start_at = 'body' if running_content_start_at == 'toc' && !insert_toc
            end
            if ::Integer === (page_numbering_start_at = @theme.page_numbering_start_at || 'body')
              page_numbering_body_offset = body_offset + [page_numbering_start_at.pred, 1].max
              page_numbering_start_at = 'body'
            else
              page_numbering_body_offset = body_offset
              page_numbering_start_at = 'toc' if page_numbering_start_at == 'title' && !has_title_page
              page_numbering_start_at = 'body' if page_numbering_start_at == 'toc' && !insert_toc
            end
            front_matter_sig = [running_content_start_at, page_numbering_start_at]
            # table values are number of pages to skip before starting running content and page numbering, respectively
            num_front_matter_pages = {
              %w(title title) => [zero_page_offset, zero_page_offset],
              %w(title toc) => [zero_page_offset, first_page_offset],
              %w(title body) => [zero_page_offset, page_numbering_body_offset],
              %w(toc title) => [first_page_offset, zero_page_offset],
              %w(toc toc) => [first_page_offset, first_page_offset],
              %w(toc body) => [first_page_offset, page_numbering_body_offset],
              %w(body title) => [running_content_body_offset, zero_page_offset],
              %w(body toc) => [running_content_body_offset, first_page_offset],
            }[front_matter_sig] || [running_content_body_offset, page_numbering_body_offset]
          else
            num_front_matter_pages = [body_start_page_number - 1] * 2
          end

          @index.start_page_number = num_front_matter_pages[1] + 1
          doc.set_attr 'pdf-anchor', (doc_anchor = derive_anchor_from_id doc.id, 'top')
          add_dest_for_block doc, doc_anchor

          convert_section generate_manname_section doc if doc.doctype == 'manpage' && (doc.attr? 'manpurpose')

          traverse doc

          # NOTE: for a book, these are leftover footnotes; for an article this is everything
          outdent_section { layout_footnotes doc }

          # NOTE: delete orphaned page (a page was created but there was no additional content)
          # QUESTION should we delete page if document is empty? (leaving no pages?)
          if page_count > 1
            go_to_page page_count unless last_page?
            delete_page if page.empty?
          end

          toc_page_nums = @toc_extent ? (layout_toc doc, toc_num_levels, @toc_extent[:page_nums].first, @toc_extent[:start_y], num_front_matter_pages[1]) : []
        end

        unless page_count < body_start_page_number
          layout_running_content :header, doc, skip: num_front_matter_pages, body_start_page_number: body_start_page_number unless doc.noheader || @theme.header_height.to_f == 0
          layout_running_content :footer, doc, skip: num_front_matter_pages, body_start_page_number: body_start_page_number unless doc.nofooter || @theme.footer_height.to_f == 0
        end

        add_outline doc, (doc.attr 'outlinelevels', toc_num_levels), toc_page_nums, num_front_matter_pages[1], has_front_cover
        if !state.pages.empty? && (initial_zoom = @theme.page_initial_zoom)
          case initial_zoom.to_sym
          when :Fit
            catalog.data[:OpenAction] = dest_fit state.pages[0]
          when :FitV
            catalog.data[:OpenAction] = dest_fit_vertically 0, state.pages[0]
          when :FitH
            catalog.data[:OpenAction] = dest_fit_horizontally page_height, state.pages[0]
          end
        end
        catalog.data[:ViewerPreferences] = { DisplayDocTitle: true }

        stamp_foreground_image doc, has_front_cover
        layout_cover_page doc, :back
        remove_tmp_files
        nil
      end

      # NOTE: embedded only makes sense if perhaps we are building
      # on an existing Prawn::Document instance; for now, just treat
      # it the same as a full document.
      alias convert_embedded convert_document

      def init_pdf doc
        (instance_variables - @initial_instance_variables).each {|ivar| remove_instance_variable ivar } if state
        pdf_opts = build_pdf_options doc, (theme = load_theme doc)
        # QUESTION should page options be preserved? (otherwise, not readily available)
        #@page_opts = { size: pdf_opts[:page_size], layout: pdf_opts[:page_layout] }
        ((::Prawn::Document.instance_method :initialize).bind self).call pdf_opts
        renderer.min_version (@pdf_version = PDFVersions[doc.attr 'pdf-version'])
        @page_margin_by_side = { recto: page_margin, verso: page_margin, cover: page_margin }
        if (@media = doc.attr 'media', 'screen') == 'prepress'
          @ppbook = doc.doctype == 'book'
          page_margin_recto = @page_margin_by_side[:recto]
          if (page_margin_outer = theme.page_margin_outer)
            page_margin_recto[1] = @page_margin_by_side[:verso][3] = page_margin_outer
          end
          if (page_margin_inner = theme.page_margin_inner)
            page_margin_recto[3] = @page_margin_by_side[:verso][1] = page_margin_inner
          end
          # NOTE: prepare scratch document to use page margin from recto side (which has same width as verso side)
          set_page_margin page_margin_recto unless page_margin_recto == page_margin
        else
          @ppbook = nil
        end
        # QUESTION should ThemeLoader handle registering fonts instead?
        register_fonts theme.font_catalog, (doc.attr 'pdf-fontsdir', 'GEM_FONTS_DIR')
        default_kerning theme.base_font_kerning != 'none'
        @fallback_fonts = [*theme.font_fallbacks]
        @allow_uri_read = doc.attr? 'allow-uri-read'
        @cache_uri = doc.attr? 'cache-uri'
        @tmp_files = {}
        if (bg_image = resolve_background_image doc, theme, 'page-background-image') && bg_image[0]
          @page_bg_image = { verso: bg_image, recto: bg_image }
        else
          @page_bg_image = { verso: nil, recto: nil }
        end
        if (bg_image = resolve_background_image doc, theme, 'page-background-image-verso')
          @page_bg_image[:verso] = bg_image[0] && bg_image
        end
        if (bg_image = resolve_background_image doc, theme, 'page-background-image-recto')
          @page_bg_image[:recto] = bg_image[0] && bg_image
        end
        @page_bg_color = resolve_theme_color :page_background_color, 'FFFFFF'
        @root_font_size = theme.base_font_size || 12
        @font_color = theme.base_font_color || '000000'
        @text_decoration_width = theme.base_text_decoration_width
        @base_align = (align = doc.attr 'text-align') && (TextAlignmentNames.include? align) ? align : theme.base_align
        @cjk_line_breaks = doc.attr? 'scripts', 'cjk'
        if (hyphen_lang = doc.attr 'hyphens') &&
            ((defined? ::Text::Hyphen::VERSION) || !(Helpers.require_library 'text/hyphen', 'text-hyphen', :warn).nil?)
          hyphen_lang = doc.attr 'lang' if hyphen_lang.empty?
          hyphen_lang = 'en_us' if hyphen_lang.nil_or_empty? || hyphen_lang == 'en'
          hyphen_lang = (hyphen_lang.tr '-', '_').downcase
          @hyphenator = ::Text::Hyphen.new language: hyphen_lang
        end
        @text_transform = nil
        @list_numerals = []
        @list_bullets = []
        @footnotes = []
        @conum_glyphs = ConumSets[@theme.conum_glyphs || 'circled'] || (@theme.conum_glyphs.split ',').map {|r|
          from, to = r.rstrip.split '-', 2
          to ? ((get_char from)..(get_char to)).to_a : [(get_char from)]
        }.flatten
        @section_indent = (val = @theme.section_indent) && (inflate_indent val)
        @toc_max_pagenum_digits = (doc.attr 'toc-max-pagenum-digits', 3).to_i
        @index = IndexCatalog.new
        # NOTE: we have to init Pdfmark class here while we have reference to the doc
        @pdfmark = (doc.attr? 'pdfmark') ? (Pdfmark.new doc) : nil
        @optimize = doc.attr 'optimize'
        init_scratch_prototype
        self
      end

      def load_theme doc
        @theme ||= begin # rubocop:disable Naming/MemoizedInstanceVariableName
          if (theme = doc.options[:pdf_theme])
            @themesdir = ::File.expand_path theme.__dir__ || (doc.attr 'pdf-themesdir') || (doc.attr 'pdf-stylesdir') || ::Dir.pwd
          elsif (theme_name = (doc.attr 'pdf-theme') || (doc.attr 'pdf-style'))
            theme = ThemeLoader.load_theme theme_name, (user_themesdir = (doc.attr 'pdf-themesdir') || (doc.attr 'pdf-stylesdir'))
            @themesdir = theme.__dir__
          else
            @themesdir = (theme = ThemeLoader.load_theme).__dir__
          end
          theme
        rescue
          if user_themesdir
            message = %(could not locate or load the pdf theme `#{theme_name}' in #{user_themesdir})
          else
            message = %(could not locate or load the built-in pdf theme `#{theme_name}')
          end
          message += %( because of #{$!.class} #{$!.message}) unless ::SystemCallError === $!
          logger.error %(#{message}; reverting to default theme)
          @themesdir = (theme = ThemeLoader.load_theme).__dir__
          theme
        end
      end

      def build_pdf_options doc, theme
        case (page_margin = (doc.attr 'pdf-page-margin') || theme.page_margin)
        when ::Array
          page_margin = page_margin.slice 0, 4 if page_margin.length > 4
          page_margin = page_margin.map {|v| ::Numeric === v ? v : (str_to_pt v.to_s) }
        when ::Numeric
          page_margin = [page_margin]
        when ::String
          if page_margin.empty?
            page_margin = nil
          elsif (page_margin.start_with? '[') && (page_margin.end_with? ']')
            if (page_margin = (page_margin.slice 1, page_margin.length - 2).rstrip).empty?
              page_margin = [0]
            else
              if (page_margin = page_margin.split ',', -1).length > 4
                page_margin = page_margin.slice 0, 4
              end
              page_margin = page_margin.map {|v| str_to_pt v.rstrip }
            end
          else
            page_margin = [(str_to_pt page_margin)]
          end
        else
          page_margin = nil
        end

        if (doc.attr? 'pdf-page-size') && PageSizeRx =~ (doc.attr 'pdf-page-size')
          # e.g, [8.5in, 11in]
          if $1
            page_size = [$1, $2]
          # e.g, 8.5in x 11in
          elsif $3
            page_size = [$3, $4]
          # e.g, A4
          else
            page_size = $&
          end
        else
          page_size = theme.page_size
        end

        case page_size
        when ::String
          # TODO: extract helper method to check for named page size
          page_size = page_size.upcase
          page_size = nil unless ::PDF::Core::PageGeometry::SIZES.key? page_size
        when ::Array
          page_size = (page_size.slice 0, 2).fill(0..1) {|i| page_size[i] || 0 } unless page_size.size == 2
          page_size = page_size.map do |dim|
            if ::Numeric === dim
              # dimension cannot be less than 0
              dim > 0 ? dim : break
            elsif ::String === dim && MeasurementPartsRx =~ dim
              # NOTE: truncate to max precision retained by PDF::Core
              (to_pt $1.to_f, $2).truncate 4
            else
              break
            end
          end
        else
          page_size = nil
        end

        if (page_layout = (doc.attr 'pdf-page-layout') || theme.page_layout).nil_or_empty? ||
            !PageLayouts.include?(page_layout = page_layout.to_sym)
          page_layout = nil
        end

        {
          margin: (page_margin || 36),
          page_size: (page_size || 'A4'),
          page_layout: (page_layout || :portrait),
          info: (build_pdf_info doc),
          compress: (doc.attr? 'compress'),
          skip_page_creation: true,
          text_formatter: (FormattedText::Formatter.new theme: theme),
        }
      end

      # FIXME: Pdfmark should use the PDF info result
      def build_pdf_info doc
        info = {}
        # FIXME: use sanitize: :plain_text once available
        if (doctitle = doc.header? ? doc.doctitle : (doc.attr 'untitled-label'))
          info[:Title] = (sanitize doctitle).as_pdf
        end
        info[:Author] = (doc.attr 'authors').as_pdf if doc.attr? 'authors'
        info[:Subject] = (doc.attr 'subject').as_pdf if doc.attr? 'subject'
        info[:Keywords] = (doc.attr 'keywords').as_pdf if doc.attr? 'keywords'
        info[:Producer] = (doc.attr 'publisher').as_pdf if doc.attr? 'publisher'
        if doc.attr? 'reproducible'
          info[:Creator] = 'Asciidoctor PDF, based on Prawn'.as_pdf
          info[:Producer] ||= (info[:Author] || info[:Creator])
        else
          info[:Creator] = %(Asciidoctor PDF #{::Asciidoctor::PDF::VERSION}, based on Prawn #{::Prawn::VERSION}).as_pdf
          info[:Producer] ||= (info[:Author] || info[:Creator])
          # NOTE: since we don't track the creation date of the input file, we map the ModDate header to the last modified
          # date of the input document and the CreationDate header to the date the PDF was produced by the converter.
          info[:ModDate] = (::Time.parse doc.attr 'docdatetime') rescue (now ||= ::Time.now)
          info[:CreationDate] = (::Time.parse doc.attr 'localdatetime') rescue (now || ::Time.now)
        end
        info
      end

      # NOTE: init_page is called within a float context
      # NOTE: init_page is not called for imported pages, front and back cover pages, and other image pages
      def init_page *_args
        # NOTE: we assume in prepress that physical page number reflects page side
        if @media == 'prepress' &&
            (next_page_margin = @page_margin_by_side[page_number == 1 ? :cover : page_side]) != page_margin
          set_page_margin next_page_margin
        end
        if @page_bg_color && @page_bg_color != 'FFFFFF'
          tare = true
          fill_absolute_bounds @page_bg_color
        end
        if (bg_image = @page_bg_image[page_side])
          tare = true
          # NOTE: float is necessary since prawn-svg may mess with cursor position
          float { canvas { image bg_image[0], ({ position: :center, vposition: :center }.merge bg_image[1]) } }
        end
        page.tare_content_stream if tare
      end

      def convert_section sect, _opts = {}
        if sect.sectname == 'abstract'
          # HACK: cheat a bit to hide this section from TOC; TOC should filter these sections
          sect.context = :open
          return convert_abstract sect
        end

        type = nil
        title = sect.numbered_title formal: true
        sep = (sect.attr 'separator', nil, false) || (sect.document.attr 'title-separator') || ''
        if !sep.empty? && title.include?(sep = %(#{sep} ))
          title, _, subtitle = title.rpartition sep
          title = %(#{title}\n<em class="subtitle">#{subtitle}</em>)
        end
        theme_font :heading, level: (hlevel = sect.level + 1) do
          align = (@theme[%(heading_h#{hlevel}_align)] || @theme.heading_align || @base_align).to_sym
          if sect.part_or_chapter?
            if sect.chapter?
              type = :chapter
              if @theme.heading_chapter_break_before == 'auto'
                start_new_chapter sect if @theme.heading_part_break_after == 'always' && sect == sect.parent.sections[0]
              else
                start_new_chapter sect
              end
            else
              type = :part
              start_new_part sect unless @theme.heading_part_break_before == 'auto'
            end
          end
          unless at_page_top?
            # FIXME: this height doesn't account for impact of text transform or inline formatting
            heading_height =
              (height_of_typeset_text title, line_height: (@theme[%(heading_h#{hlevel}_line_height)] || @theme.heading_line_height)) +
              (@theme[%(heading_h#{hlevel}_margin_top)] || @theme.heading_margin_top || 0) +
              (@theme[%(heading_h#{hlevel}_margin_bottom)] || @theme.heading_margin_bottom || 0)
            heading_height += (@theme.heading_min_height_after || 0) if sect.blocks?
            start_new_page unless cursor > heading_height
          end
          # QUESTION should we store pdf-page-start, pdf-anchor & pdf-destination in internal map?
          sect.set_attr 'pdf-page-start', (start_pgnum = page_number)
          # QUESTION should we just assign the section this generated id?
          # NOTE: section must have pdf-anchor in order to be listed in the TOC
          sect.set_attr 'pdf-anchor', (sect_anchor = derive_anchor_from_id sect.id, %(#{start_pgnum}-#{y.ceil}))
          add_dest_for_block sect, sect_anchor
          case type
          when :part
            layout_part_title sect, title, align: align, level: hlevel
          when :chapter
            layout_chapter_title sect, title, align: align, level: hlevel
          else
            layout_heading title, align: align, level: hlevel, outdent: true
          end
        end

        if sect.sectname == 'index'
          outdent_section { convert_index_section sect }
        else
          traverse sect
        end
        outdent_section { layout_footnotes sect } if type == :chapter
        sect.set_attr 'pdf-page-end', page_number
      end

      def indent_section
        if (values = @section_indent)
          indent(values[0], values[1]) { yield }
        else
          yield
        end
      end

      def outdent_section enabled = true
        if enabled && (values = @section_indent)
          indent(-values[0], -values[1]) { yield }
        else
          yield
        end
      end

      # QUESTION if a footnote ref appears in a separate chapter, should the footnote def be duplicated?
      def layout_footnotes node
        return if (fns = (doc = node.document).footnotes - @footnotes).empty?
        theme_margin :footnotes, :top
        theme_font :footnotes do
          (title = doc.attr 'footnotes-title') && (layout_caption title, category: :footnotes)
          item_spacing = @theme.footnotes_item_spacing || 0
          fns.each do |fn|
            layout_prose %(<a id="_footnotedef_#{index = fn.index}">#{DummyText}</a>[<a anchor="_footnoteref_#{index}">#{index}</a>] #{fn.text}), margin_bottom: item_spacing, hyphenate: true
          end
          @footnotes += fns
        end
        nil
      end

      def convert_floating_title node
        add_dest_for_block node if node.id
        hlevel = node.level.next
        unless (align = resolve_alignment_from_role node.roles)
          align = (@theme[%(heading_h#{hlevel}_align)] || @theme.heading_align || @base_align).to_sym
        end
        # QUESTION should we decouple styles from section titles?
        theme_font :heading, level: hlevel do
          layout_heading node.title, align: align, level: hlevel, outdent: (node.parent.context == :section)
        end
      end

      def convert_abstract node
        add_dest_for_block node if node.id
        outdent_section do
          pad_box @theme.abstract_padding do
            theme_font :abstract_title do
              layout_prose node.title, align: (@theme.abstract_title_align || @base_align).to_sym, margin_top: (@theme.heading_margin_top || 0), margin_bottom: (@theme.heading_margin_bottom || 0), line_height: @theme.heading_line_height
            end if node.title?
            theme_font :abstract do
              prose_opts = { line_height: @theme.abstract_line_height, align: (@theme.abstract_align || @base_align).to_sym, hyphenate: true }
              if (text_indent = @theme.prose_text_indent || 0) > 0
                prose_opts[:indent_paragraphs] = text_indent
              end
              # FIXME: allow theme to control more first line options
              if (line1_font_style = @theme.abstract_first_line_font_style) && line1_font_style.to_sym != font_style
                first_line_options = { styles: [font_style, line1_font_style.to_sym] }
              end
              if (line1_font_color = @theme.abstract_first_line_font_color)
                (first_line_options ||= {})[:color] = line1_font_color
              end
              prose_opts[:first_line_options] = first_line_options if first_line_options
              # FIXME: make this cleaner!!
              if node.blocks?
                node.blocks.each do |child|
                  # FIXME: is playback necessary here?
                  child.document.playback_attributes child.attributes
                  if child.context == :paragraph
                    layout_prose child.content, ((align = resolve_alignment_from_role child.roles) ? (prose_opts.merge align: align) : prose_opts.dup)
                    prose_opts.delete :first_line_options
                  else
                    # FIXME: this could do strange things if the wrong kind of content shows up
                    traverse child
                  end
                end
              elsif node.content_model != :compound && (string = node.content)
                if (align = resolve_alignment_from_role node.roles)
                  prose_opts[:align] = align
                end
                layout_prose string, prose_opts
              end
            end
          end
          # QUESTION should we be adding margin below the abstract??
          #theme_margin :block, :bottom
        end
      end

      def convert_preamble node
        # FIXME: core should not be promoting paragraph to preamble if there are no sections
        if node.blocks? && (first_block = node.blocks[0]).context == :paragraph && node.document.sections?
          first_block.add_role 'lead' unless first_block.role?
        end
        traverse node
      end

      def convert_paragraph node
        add_dest_for_block node if node.id
        prose_opts = { margin_bottom: 0, hyphenate: true }
        lead = (roles = node.roles).include? 'lead'
        if (align = resolve_alignment_from_role roles)
          prose_opts[:align] = align
        end

        if (text_indent = @theme.prose_text_indent || 0) > 0
          prose_opts[:indent_paragraphs] = text_indent
        end

        # TODO: check if we're within one line of the bottom of the page
        # and advance to the next page if so (similar to logic for section titles)
        layout_caption node.title if node.title?

        if lead
          theme_font :lead do
            layout_prose node.content, prose_opts
          end
        else
          layout_prose node.content, prose_opts
        end

        if (margin_inner_val = @theme.prose_margin_inner) &&
            (next_block = (siblings = node.parent.blocks)[(siblings.index node) + 1]) && next_block.context == :paragraph
          margin_bottom margin_inner_val
        else
          margin_bottom @theme.prose_margin_bottom
        end
      end

      def convert_admonition node
        add_dest_for_block node if node.id
        theme_margin :block, :top
        type = node.attr 'name'
        label_align = (@theme.admonition_label_align || :center).to_sym
        # TODO: allow vertical_align to be a number
        if (label_valign = (@theme.admonition_label_vertical_align || :middle).to_sym) == :middle
          label_valign = :center
        end
        if (label_min_width = @theme.admonition_label_min_width)
          label_min_width = label_min_width.to_f
        end
        icons = ((doc = node.document).attr? 'icons') ? (doc.attr 'icons') : nil
        if (data_uri_enabled = doc.attr? 'data-uri')
          doc.remove_attr 'data-uri'
        end
        if icons == 'font' && !(node.attr? 'icon', nil, false)
          label_text = type.to_sym
          icon_data = admonition_icon_data label_text
          label_width = label_min_width || ((icon_size = icon_data[:size] || 24) * 1.5)
        # NOTE: icon_uri will consider icon attribute on node first, then type
        # QUESTION should we use resolve_image_path here?
        elsif icons && (icon_path = node.icon_uri type) &&
            (icon_path = node.normalize_system_path icon_path, nil, nil, target_name: 'admonition icon') &&
            (::File.readable? icon_path)
          icons = true
          # TODO: introduce @theme.admonition_image_width? or use size key from admonition_icon_<name>?
          label_width = label_min_width || 36.0
        else
          if icons
            icons = nil
            logger.warn %(admonition icon not found or not readable: #{icon_path}) unless scratch?
          end
          label_text = node.caption
          theme_font :admonition_label do
            theme_font %(admonition_label_#{type}) do
              label_text = transform_text label_text, @text_transform if @text_transform
              label_width = rendered_width_of_string label_text
              label_width = label_min_width if label_min_width && label_min_width > label_width
            end
          end
        end
        doc.set_attr 'data-uri', '' if data_uri_enabled
        unless ::Array === (cpad = @theme.admonition_padding)
          cpad = ::Array.new 4, cpad
        end
        unless ::Array === (lpad = @theme.admonition_label_padding || cpad)
          lpad = ::Array.new 4, lpad
        end
        # FIXME: this shift stuff is a real hack until we have proper margin collapsing
        shift_base = @theme.prose_margin_bottom
        shift_top = shift_base / 3.0
        shift_bottom = (shift_base * 2) / 3.0
        keep_together do |box_height = nil|
          push_scratch doc if scratch?
          theme_fill_and_stroke_block :admonition, box_height if box_height
          pad_box [0, cpad[1], 0, lpad[3]] do
            if box_height
              label_height = [box_height, cursor].min
              if (rule_color = @theme.admonition_column_rule_color) &&
                  (rule_width = @theme.admonition_column_rule_width || @theme.base_border_width) && rule_width > 0
                float do
                  rule_height = box_height
                  while rule_height > 0
                    rule_segment_height = [rule_height, cursor].min
                    bounding_box [0, cursor], width: label_width + lpad[1], height: rule_segment_height do
                      stroke_vertical_rule rule_color,
                          at: bounds.right,
                          line_style: (@theme.admonition_column_rule_style || :solid).to_sym,
                          line_width: rule_width
                    end
                    advance_page if (rule_height -= rule_segment_height) > 0
                  end
                end
              end
              float do
                bounding_box [0, cursor], width: label_width, height: label_height do
                  if icons == 'font'
                    # FIXME: we assume icon is square
                    icon_size = fit_icon_to_bounds icon_size
                    # NOTE: Prawn's vertical center is not reliable, so calculate it manually
                    if label_valign == :center
                      label_valign = :top
                      if (vcenter_pos = (label_height - icon_size) * 0.5) > 0
                        move_down vcenter_pos
                      end
                    end
                    icon icon_data[:name],
                        valign: label_valign,
                        align: label_align,
                        color: icon_data[:stroke_color],
                        size: icon_size
                  elsif icons
                    if (::Asciidoctor::Image.format icon_path) == 'svg'
                      begin
                        svg_obj = ::Prawn::SVG::Interface.new ::File.read(icon_path, mode: 'r:UTF-8'), self,
                            position: label_align,
                            vposition: label_valign,
                            width: label_width,
                            height: label_height,
                            fallback_font_name: fallback_svg_font_name,
                            enable_web_requests: allow_uri_read,
                            enable_file_requests_with_root: (::File.dirname icon_path),
                            cache_images: cache_uri
                        if (icon_height = (svg_size = svg_obj.document.sizing).output_height) > label_height
                          icon_width = (svg_obj.resize height: (icon_height = label_height)).output_width
                        else
                          icon_width = svg_size.output_width
                        end
                        svg_obj.draw
                        svg_obj.document.warnings.each do |icon_warning|
                          logger.warn %(problem encountered in image: #{icon_path}; #{icon_warning})
                        end unless scratch?
                      rescue
                        logger.warn %(could not embed admonition icon: #{icon_path}; #{$!.message}) unless scratch?
                      end
                    else
                      begin
                        image_obj, image_info = ::File.open(icon_path, 'rb') {|fd| build_image_object fd }
                        icon_aspect_ratio = image_info.width.fdiv image_info.height
                        # NOTE: don't scale image up if smaller than label_width
                        icon_width = [(to_pt image_info.width, :px), label_width].min
                        if (icon_height = icon_width * (1 / icon_aspect_ratio)) > label_height
                          icon_width *= label_height / icon_height
                          icon_height = label_height # rubocop:disable Lint/UselessAssignment
                        end
                        embed_image image_obj, image_info, width: icon_width, position: label_align, vposition: label_valign
                      rescue
                        # QUESTION should we show the label in this case?
                        logger.warn %(could not embed admonition icon: #{icon_path}; #{$!.message}) unless scratch?
                      end
                    end
                  else
                    # IMPORTANT the label must fit in the alotted space or it shows up on another page!
                    # QUESTION anyway to prevent text overflow in the case it doesn't fit?
                    theme_font :admonition_label do
                      theme_font %(admonition_label_#{type}) do
                        # NOTE: Prawn's vertical center is not reliable, so calculate it manually
                        if label_valign == :center
                          label_valign = :top
                          if (vcenter_pos = (label_height - (height_of_typeset_text label_text, line_height: 1)) * 0.5) > 0
                            move_down vcenter_pos
                          end
                        end
                        @text_transform = nil # already applied to label
                        layout_prose label_text,
                            align: label_align,
                            valign: label_valign,
                            line_height: 1,
                            margin: 0,
                            inline_format: false
                      end
                    end
                  end
                end
              end
            end
            pad_box [cpad[0], 0, cpad[2], label_width + lpad[1] + cpad[3]] do
              move_down shift_top
              layout_caption node.title, category: :admonition if node.title?
              theme_font :admonition do
                traverse node
              end
              # FIXME: HACK compensate for margin bottom of admonition content
              move_up shift_bottom unless at_page_top?
            end
          end
          pop_scratch doc if scratch?
        end
        theme_margin :block, :bottom
      end

      def convert_example node
        add_dest_for_block node if node.id
        theme_margin :block, :top
        caption_height = node.title? ? (layout_caption node, category: :example, dry_run: true) : 0
        keep_together do |box_height = nil|
          push_scratch node.document if scratch?
          if box_height
            theme_fill_and_stroke_block :example, box_height, caption_node: node
          else
            move_down caption_height
          end
          pad_box @theme.example_padding do
            theme_font :example do
              traverse node
            end
          end
          pop_scratch node.document if scratch?
        end
        theme_margin :block, :bottom
      end

      def convert_open node
        if node.style == 'abstract'
          convert_abstract node
        else
          doc = node.document
          keep_together_if node.option? 'unbreakable' do
            push_scratch doc if scratch?
            add_dest_for_block node if node.id
            layout_caption node.title if node.title?
            traverse node
            pop_scratch doc if scratch?
          end
        end
      end

      def convert_quote_or_verse node
        add_dest_for_block node if node.id
        theme_margin :block, :top
        category = node.context == :quote ? :blockquote : :verse
        unless (b_left_width = @theme[%(#{category}_border_left_width)]) && b_left_width > 0
          b_left_width = nil
          if (b_width = @theme[%(#{category}_border_width)])
            b_width = nil unless b_width > 0
          end
        end
        keep_together do |box_height = nil|
          push_scratch node.document if scratch?
          theme_fill_and_stroke_block category, box_height, border_width: b_width if box_height && (b_width || @theme[%(#{category}_background_color)])
          start_page_number = page_number
          start_cursor = cursor
          caption_height = node.title? ? (layout_caption node, category: category) : 0
          pad_box @theme[%(#{category}_padding)] do
            theme_font category do
              if category == :blockquote
                traverse node
              else # verse
                content = guard_indentation node.content
                layout_prose content, normalize: false, align: :left, hyphenate: true
              end
            end
            if node.attr? 'attribution', nil, false
              theme_font %(#{category}_cite) do
                layout_prose %(#{EmDash} #{[(node.attr 'attribution'), (node.attr 'citetitle', nil, false)].compact.join ', '}), align: :left, normalize: false
              end
            end
          end
          # FIXME: we want to draw graphics before content, but box_height is not reliable when spanning pages
          # FIXME: border extends to bottom of content area if block terminates at bottom of page
          if box_height && b_left_width
            b_color = @theme[%(#{category}_border_color)]
            page_spread = page_number - start_page_number + 1
            end_cursor = cursor
            go_to_page start_page_number
            move_cursor_to start_cursor
            page_spread.times do |i|
              if i == 0
                y_draw = cursor
                b_height = page_spread > 1 ? y_draw : (y_draw - end_cursor)
              else
                bounds.move_past_bottom
                y_draw = cursor
                b_height = page_spread - 1 == i ? (y_draw - end_cursor) : y_draw
              end
              # NOTE: skip past caption if present
              if caption_height > 0
                if caption_height > cursor
                  caption_height -= cursor
                  next # keep skipping, caption is on next page
                end
                y_draw -= caption_height
                b_height -= caption_height
                caption_height = 0
              end
              # NOTE: b_height is 0 when block terminates at bottom of page
              next if b_height == 0
              bounding_box [0, y_draw], width: bounds.width, height: b_height do
                stroke_vertical_rule b_color, line_width: b_left_width, at: b_left_width * 0.5
              end
            end
          end
          pop_scratch node.document if scratch?
        end
        theme_margin :block, :bottom
      end

      alias convert_quote convert_quote_or_verse
      alias convert_verse convert_quote_or_verse

      def convert_sidebar node
        add_dest_for_block node if node.id
        theme_margin :block, :top
        keep_together do |box_height = nil|
          push_scratch node.document if scratch?
          theme_fill_and_stroke_block :sidebar, box_height if box_height
          pad_box @theme.sidebar_padding do
            theme_font :sidebar_title do
              # QUESTION should we allow margins of sidebar title to be customized?
              layout_prose node.title, align: (@theme.sidebar_title_align || @base_align).to_sym, margin_top: 0, margin_bottom: (@theme.heading_margin_bottom || 0), line_height: @theme.heading_line_height
            end if node.title?
            theme_font :sidebar do
              traverse node
            end
          end
          pop_scratch node.document if scratch?
        end
        theme_margin :block, :bottom
      end

      def convert_colist node
        # HACK: undo the margin below previous listing or literal block
        # TODO: allow this to be set using colist_margin_top
        unless at_page_top?
          if (self_idx = node.parent.blocks.index node) && self_idx > 0 &&
              [:listing, :literal].include?(node.parent.blocks[self_idx - 1].context)
            move_up @theme.block_margin_bottom - @theme.outline_list_item_spacing
          end
        end
        add_dest_for_block node if node.id
        @list_numerals << 1
        #stroke_horizontal_rule @theme.caption_border_bottom_color
        line_metrics = theme_font(:conum) { calc_line_metrics @theme.base_line_height }
        node.items.each do |item|
          allocate_space_for_list_item line_metrics
          convert_colist_item item
        end
        @list_numerals.pop
        # correct bottom margin of last item
        list_margin_bottom = @theme.prose_margin_bottom
        margin_bottom list_margin_bottom - @theme.outline_list_item_spacing
      end

      def convert_colist_item node
        marker_width = nil
        @list_numerals << (index = @list_numerals.pop).next
        theme_font :conum do
          marker_width = rendered_width_of_string %(#{marker = conum_glyph index}x)
          float do
            bounding_box [0, cursor], width: marker_width do
              theme_font :conum do
                layout_prose marker, align: :center, line_height: @theme.conum_line_height, inline_format: false, margin: 0
              end
            end
          end
        end

        indent marker_width do
          traverse_list_item node, :colist, margin_bottom: @theme.outline_list_item_spacing, normalize_line_height: true
        end
      end

      def convert_dlist node
        add_dest_for_block node if node.id

        case (style = node.style)
        when 'unordered', 'ordered'
          if style == 'unordered'
            list_style = :ulist
            (markers = @list_bullets) << :disc
          else
            list_style = :olist
            (markers = @list_numerals) << 1
          end
          list = List.new node.parent, list_style
          stack_subject = node.has_role? 'stack'
          subject_stop = node.attr 'subject-stop', (stack_subject ? nil : ':'), false
          node.items.each do |subjects, dd|
            subject = [*subjects].first.text
            list_item_text = %(+++<strong>#{subject}#{(StopPunctRx.match? sanitize subject) ? '' : subject_stop}</strong>#{dd.text? ? "#{stack_subject ? '<br>' : ' '}#{dd.text}" : ''}+++)
            list_item = ListItem.new list, list_item_text
            dd.blocks.each {|it| list_item << it }
            list << list_item
          end
          convert_outline_list list
          markers.pop
        when 'horizontal'
          table_data = []
          term_padding = desc_padding = term_line_metrics = term_inline_format = term_kerning = nil
          max_term_width = 0
          theme_font :description_list_term do
            if (term_font_styles = font_styles).empty?
              term_inline_format = true
            else
              term_inline_format = [inherited: { styles: term_font_styles }]
            end
            term_line_metrics = calc_line_metrics @theme.description_list_term_line_height || @theme.base_line_height
            term_padding = [term_line_metrics.padding_top, 10, (@theme.prose_margin_bottom || 0) * 0.5 + term_line_metrics.padding_bottom, 10]
            desc_padding = [0, 10, (@theme.prose_margin_bottom || 0) * 0.5, 10]
            term_kerning = default_kerning?
          end
          node.items.each do |terms, desc|
            term_text = terms.map(&:text).join ?\n
            if (term_width = width_of term_text, inline_format: term_inline_format, kerning: term_kerning) > max_term_width
              max_term_width = term_width
            end
            row_data = [{
              text_color: @font_color,
              kerning: term_kerning,
              content: term_text,
              inline_format: term_inline_format,
              padding: term_padding,
              leading: term_line_metrics.leading,
              # FIXME: prawn-table doesn't have support for final_gap option
              #final_gap: term_line_metrics.final_gap,
              valign: :top,
            }]
            desc_container = Block.new desc, :open
            desc_container << (Block.new desc_container, :paragraph, source: (desc.instance_variable_get :@text), subs: :default) if desc.text?
            desc.blocks.each {|b| desc_container << b } if desc.block?
            row_data << {
              content: (::Prawn::Table::Cell::AsciiDoc.new self, content: desc_container, text_color: @font_color, padding: desc_padding, valign: :top),
            }
            table_data << row_data
          end
          max_term_width += (term_padding[1] + term_padding[3])
          term_column_width = [max_term_width, bounds.width * 0.5].min
          table table_data, position: :left, cell_style: { border_width: 0 }, column_widths: [term_column_width] do
            @pdf.layout_table_caption node if node.title?
          end
          margin_bottom (@theme.prose_margin_bottom || 0) * 0.5
        when 'qanda'
          @list_numerals << '1'
          convert_outline_list node
          @list_numerals.pop
        else
          # TODO: check if we're within one line of the bottom of the page
          # and advance to the next page if so (similar to logic for section titles)
          layout_caption node.title, category: :description_list if node.title?

          term_line_height = @theme.description_list_term_line_height || @theme.base_line_height
          line_metrics = theme_font(:description_list_term) { calc_line_metrics term_line_height }
          node.items.each do |terms, desc|
            # NOTE: don't orphan the terms (keep together terms and at least one line of content)
            allocate_space_for_list_item line_metrics, (terms.size + 1), ((@theme.description_list_term_spacing || 0) + 0.05)
            theme_font :description_list_term do
              if (term_font_styles = font_styles).empty?
                term_font_styles = nil
              end
              terms.each do |term|
                # QUESTION should we pass down styles in other calls to layout_prose
                layout_prose term.text, margin_top: 0, margin_bottom: @theme.description_list_term_spacing, align: :left, line_height: term_line_height, normalize_line_height: true, styles: term_font_styles
              end
            end
            indent(@theme.description_list_description_indent || 0) do
              traverse_list_item desc, :dlist_desc, normalize_line_height: true
            end if desc
          end
        end
      end

      def convert_olist node
        add_dest_for_block node if node.id
        # TODO: move list_numeral resolve to a method
        case node.style
        when 'arabic'
          list_numeral = 1
        when 'decimal'
          list_numeral = '01'
        when 'loweralpha'
          list_numeral = 'a'
        when 'upperalpha'
          list_numeral = 'A'
        when 'lowerroman'
          list_numeral = RomanNumeral.new 'i'
        when 'upperroman'
          list_numeral = RomanNumeral.new 'I'
        when 'lowergreek'
          list_numeral = LowercaseGreekA
        when 'unstyled', 'unnumbered', 'no-bullet'
          list_numeral = nil
        when 'none'
          list_numeral = ''
        else
          list_numeral = 1
        end
        if list_numeral && list_numeral != '' &&
            (start = (node.attr 'start', nil, false) || ((node.option? 'reversed') ? node.items.size : nil))
          if (start = start.to_i) > 1
            (start - 1).times { list_numeral = list_numeral.next }
          elsif start < 1 && !(::String === list_numeral)
            (start - 1).abs.times { list_numeral = list_numeral.pred }
          end
        end
        @list_numerals << list_numeral
        convert_outline_list node
        @list_numerals.pop
      end

      def convert_ulist node
        add_dest_for_block node if node.id
        # TODO: move bullet_type to method on List (or helper method)
        if node.option? 'checklist'
          @list_bullets << :checkbox
        else
          if (style = node.style)
            case style
            when 'bibliography'
              bullet_type = :square
            when 'unstyled', 'no-bullet'
              bullet_type = nil
            else
              candidate = style.to_sym
              if Bullets.key? candidate
                bullet_type = candidate
              else
                logger.warn %(unknown unordered list style: #{candidate}) unless scratch?
                bullet_type = :disc
              end
            end
          else
            case node.outline_level
            when 1
              bullet_type = :disc
            when 2
              bullet_type = :circle
            else
              bullet_type = :square
            end
          end
          @list_bullets << bullet_type
        end
        convert_outline_list node
        @list_bullets.pop
      end

      def convert_outline_list node
        # TODO: check if we're within one line of the bottom of the page
        # and advance to the next page if so (similar to logic for section titles)
        layout_caption node.title, category: :outline_list if node.title?

        opts = {}
        if (align = resolve_alignment_from_role node.roles)
          opts[:align] = align
        elsif node.style == 'bibliography'
          opts[:align] = :left
        elsif (align = @theme.outline_list_text_align)
          # NOTE: theme setting only affects alignment of list text (not nested blocks)
          opts[:align] = align.to_sym
        end

        line_metrics = calc_line_metrics @theme.base_line_height
        complex = false
        # ...or if we want to give all items in the list the same treatment
        #complex = node.items.find(&:complex?) ? true : false
        if (node.context == :ulist && !@list_bullets[-1]) || (node.context == :olist && !@list_numerals[-1])
          if node.style == 'unstyled'
            # unstyled takes away all indentation
            list_indent = 0
          elsif (list_indent = @theme.outline_list_indent || 0) > 0
            # no-bullet aligns text with left-hand side of bullet position (as though there's no bullet)
            list_indent = [list_indent - (rendered_width_of_string %(#{node.context == :ulist ? ?\u2022 : '1.'}x)), 0].max
          end
        else
          list_indent = @theme.outline_list_indent || 0
        end
        indent list_indent do
          node.items.each do |item|
            allocate_space_for_list_item line_metrics
            convert_outline_list_item item, node, opts
          end
        end
        # NOTE: Children will provide the necessary bottom margin if last item is complex.
        # However, don't leave gap at the bottom if list is nested in an outline list
        unless complex || (node.nested? && node.parent.parent.outline?)
          # correct bottom margin of last item
          margin_bottom((@theme.prose_margin_bottom || 0) - (@theme.outline_list_item_spacing || 0))
        end
      end

      def convert_outline_list_item node, list, opts = {}
        # TODO: move this to a draw_bullet (or draw_marker) method
        marker_style = {}
        marker_style[:font_color] = @theme.outline_list_marker_font_color || @font_color
        marker_style[:font_family] = font_family
        marker_style[:font_size] = font_size
        marker_style[:line_height] = @theme.base_line_height
        case (list_type = list.context)
        when :ulist
          complex = node.complex?
          if (marker_type = @list_bullets[-1])
            if marker_type == :checkbox
              # QUESTION should we remove marker indent if not a checkbox?
              if node.attr? 'checkbox', nil, false
                marker_type = (node.attr? 'checked', nil, false) ? :checked : :unchecked
                marker = @theme[%(ulist_marker_#{marker_type}_content)] || BallotBox[marker_type]
              end
            else
              marker = @theme[%(ulist_marker_#{marker_type}_content)] || Bullets[marker_type]
            end
            [:font_color, :font_family, :font_size, :line_height].each do |prop|
              marker_style[prop] = @theme[%(ulist_marker_#{marker_type}_#{prop})] || @theme[%(ulist_marker_#{prop})] || marker_style[prop]
            end if marker
          end
        when :olist
          complex = node.complex?
          if (index = @list_numerals.pop)
            if index == ''
              marker = ''
            else
              marker = %(#{index}.)
              dir = (node.parent.option? 'reversed') ? :pred : :next
              @list_numerals << (index.public_send dir)
            end
          end
        when :dlist
          # NOTE: list.style is 'qanda'
          complex = node[1]&.complex?
          @list_numerals << (index = @list_numerals.pop).next
          marker = %(#{index}.)
        else
          complex = node.complex?
          logger.warn %(unknown list type #{list_type.inspect}) unless scratch?
          marker = @theme.ulist_marker_disc_content || Bullets[:disc]
        end

        if marker
          if marker_style[:font_family] == 'fa'
            logger.info 'deprecated fa icon set found in theme; use fas, far, or fab instead' unless scratch?
            marker_style[:font_family] = FontAwesomeIconSets.find {|candidate| (icon_font_data candidate).yaml[candidate].value? marker } || 'fas'
          end
          marker_gap = rendered_width_of_char 'x'
          font marker_style[:font_family], size: marker_style[:font_size] do
            marker_width = rendered_width_of_string marker
            # NOTE compensate if character_spacing is not applied to first character
            # see https://github.com/prawnpdf/prawn/commit/c61c5d48841910aa11b9e3d6f0e01b68ce435329
            character_spacing_correction = 0
            character_spacing(-0.5) do
              character_spacing_correction = 0.5 if (rendered_width_of_char 'x', character_spacing: -0.5) == marker_gap
            end
            marker_height = height_of_typeset_text marker, line_height: marker_style[:line_height], single_line: true
            start_position = -marker_width + -marker_gap + character_spacing_correction
            float do
              start_new_page if @media == 'prepress' && cursor < marker_height
              flow_bounding_box start_position, width: marker_width do
                layout_prose marker,
                    align: :right,
                    character_spacing: -0.5,
                    color: marker_style[:font_color],
                    inline_format: false,
                    line_height: marker_style[:line_height],
                    margin: 0,
                    normalize: false,
                    single_line: true
              end
            end
          end
        end

        if complex
          traverse_list_item node, list_type, (opts.merge normalize_line_height: true)
        else
          traverse_list_item node, list_type, (opts.merge margin_bottom: @theme.outline_list_item_spacing, normalize_line_height: true)
        end
      end

      def traverse_list_item node, list_type, opts = {}
        if list_type == :dlist # qanda
          terms, desc = node
          terms.each {|term| layout_prose %(<em>#{term.text}</em>), (opts.merge margin_top: 0, margin_bottom: @theme.description_list_term_spacing) }
          if desc
            layout_prose desc.text, (opts.merge hyphenate: true) if desc.text?
            traverse desc
          end
        else
          if (primary_text = node.text).nil_or_empty?
            layout_prose DummyText, opts unless node.blocks?
          else
            layout_prose primary_text, (opts.merge hyphenate: true)
          end
          traverse node
        end
      end

      def allocate_space_for_list_item line_metrics, number = 1, additional_gap = 0
        advance_page if !at_page_top? && cursor < (line_metrics.height + line_metrics.leading + line_metrics.padding_top + additional_gap) * number
      end

      def convert_image node, opts = {}
        node.extend ::Asciidoctor::Image unless ::Asciidoctor::Image === node
        target, image_format = node.target_and_format

        if image_format == 'gif' && !(defined? ::GMagick::Image)
          logger.warn %(GIF image format not supported. Install the prawn-gmagick gem or convert #{target} to PNG.) unless scratch?
          image_path = nil
        elsif ::Base64 === target
          image_path = target
        elsif (image_path = resolve_image_path node, target, (opts.fetch :relative_to_imagesdir, true), image_format)
          if image_format == 'pdf'
            if ::File.readable? image_path
              if (id = node.id)
                add_dest_block = proc do
                  node.set_attr 'pdf-destination', (node_dest = dest_top)
                  add_dest id, node_dest
                end
              end
              # NOTE: import_page automatically advances to next page afterwards
              # QUESTION should we add destination to top of imported page?
              if (pgnums = node.attr 'pages', nil, false)
                (resolve_pagenums pgnums).each_with_index do |pgnum, idx|
                  if idx == 0
                    import_page image_path, page: pgnum, replace: page.empty?, &add_dest_block
                  else
                    import_page image_path, page: pgnum, replace: true
                  end
                end
              else
                import_page image_path, page: [(node.attr 'page', nil, 1).to_i, 1].max, replace: page.empty?, &add_dest_block
              end
            else
              # QUESTION should we use alt text in this case?
              logger.warn %(pdf to insert not found or not readable: #{image_path}) unless scratch?
            end
            return
          elsif !(::File.readable? image_path)
            logger.warn %(image to embed not found or not readable: #{image_path}) unless scratch?
            image_path = nil
          end
        elsif image_format == 'pdf'
          # QUESTION should we use alt text in this case?
          return
        end

        theme_margin :block, :top unless (pinned = opts[:pinned])

        return on_image_error :missing, node, target, opts unless image_path

        alignment = ((node.attr 'align', nil, false) || @theme.image_align || :left).to_sym
        # TODO: support cover (aka canvas) image layout using "canvas" (or "cover") role
        width = resolve_explicit_width node.attributes, (available_w = bounds.width), support_vw: true, use_fallback: true, constrain_to_bounds: true
        # TODO: add `to_pt page_width` method to ViewportWidth type
        width = (width.to_f / 100) * page_width if ViewportWidth === width

        # NOTE: if width is not set explicitly and max-width is fit-content, caption height may not be accurate
        caption_h = node.title? ? (layout_caption node, category: :image, side: :bottom, block_align: alignment, block_width: width, max_width: @theme.image_caption_max_width, dry_run: true) : 0

        align_to_page = node.option? 'align-to-page'

        begin
          rendered_w = nil
          span_page_width_if align_to_page do
            if image_format == 'svg'
              if ::Base64 === image_path
                svg_data = ::Base64.decode64 image_path
                file_request_root = false
              else
                svg_data = ::File.read image_path, mode: 'r:UTF-8'
                file_request_root = ::File.dirname image_path
              end
              svg_obj = ::Prawn::SVG::Interface.new svg_data, self,
                  position: alignment,
                  width: width,
                  fallback_font_name: fallback_svg_font_name,
                  enable_web_requests: allow_uri_read,
                  enable_file_requests_with_root: file_request_root,
                  cache_images: cache_uri
              rendered_w = (svg_size = svg_obj.document.sizing).output_width
              if !width && (svg_obj.document.root.attributes.key? 'width')
                # NOTE: scale native width & height from px to pt and restrict width to available width
                if (adjusted_w = [available_w, (to_pt rendered_w, :px)].min) != rendered_w
                  svg_size = svg_obj.resize width: (rendered_w = adjusted_w)
                end
              end
              # NOTE: shrink image so it fits within available space; group image & caption
              if (rendered_h = svg_size.output_height) > (available_h = cursor - caption_h)
                unless pinned || at_page_top?
                  advance_page
                  available_h = cursor - caption_h
                end
                rendered_w = (svg_obj.resize height: (rendered_h = available_h)).output_width if rendered_h > available_h
              end
              image_y = y
              image_cursor = cursor
              add_dest_for_block node if node.id
              # NOTE: workaround to fix Prawn not adding fill and stroke commands on page that only has an image;
              # breakage occurs when running content (stamps) are added to page
              # seems to be resolved as of Prawn 2.2.2
              update_colors if graphic_state.color_space.empty?
              # NOTE: prawn-svg 0.24.0, 0.25.0, & 0.25.1 didn't restore font after call to draw (see mogest/prawn-svg#80)
              # NOTE: cursor advances automatically
              svg_obj.draw
              svg_obj.document.warnings.each do |img_warning|
                logger.warn %(problem encountered in image: #{image_path}; #{img_warning})
              end unless scratch?
              draw_image_border image_cursor, rendered_w, rendered_h, alignment unless node.role? && (node.has_role? 'noborder')
              if (link = node.attr 'link', nil, false)
                add_link_to_image link, { width: rendered_w, height: rendered_h }, position: alignment, y: image_y
              end
            else
              # FIXME: this code really needs to be better organized!
              # NOTE: use low-level API to access intrinsic dimensions; build_image_object caches image data previously loaded
              image_obj, image_info = ::Base64 === image_path ?
                  ::StringIO.open((::Base64.decode64 image_path), 'rb') {|fd| build_image_object fd } :
                  ::File.open(image_path, 'rb') {|fd| build_image_object fd }
              # NOTE: if width is not specified, scale native width & height from px to pt and restrict width to available width
              rendered_w, rendered_h = image_info.calc_image_dimensions width: (width || [available_w, (to_pt image_info.width, :px)].min)
              # NOTE: shrink image so it fits within available space; group image & caption
              if rendered_h > (available_h = cursor - caption_h)
                unless pinned || at_page_top?
                  advance_page
                  available_h = cursor - caption_h
                end
                rendered_w, rendered_h = image_info.calc_image_dimensions height: available_h if rendered_h > available_h
              end
              image_y = y
              image_cursor = cursor
              add_dest_for_block node if node.id
              # NOTE: workaround to fix Prawn not adding fill and stroke commands on page that only has an image;
              # breakage occurs when running content (stamps) are added to page
              # seems to be resolved as of Prawn 2.2.2
              update_colors if graphic_state.color_space.empty?
              # NOTE: specify both width and height to avoid recalculation
              embed_image image_obj, image_info, width: rendered_w, height: rendered_h, position: alignment
              draw_image_border image_cursor, rendered_w, rendered_h, alignment unless node.role? && (node.has_role? 'noborder')
              if (link = node.attr 'link', nil, false)
                add_link_to_image link, { width: rendered_w, height: rendered_h }, position: alignment, y: image_y
              end
              # NOTE: Asciidoctor disables automatic advancement of cursor for raster images, so move cursor manually
              move_down rendered_h if y == image_y
            end
          end
          layout_caption node, category: :image, side: :bottom, block_align: alignment, block_width: rendered_w, max_width: @theme.image_caption_max_width if node.title?
          theme_margin :block, :bottom unless pinned
        rescue
          on_image_error :exception, node, target, (opts.merge message: %(could not embed image: #{image_path}; #{$!.message}#{::Prawn::Errors::UnsupportedImageType === $! && !(defined? ::GMagick::Image) ? '; install prawn-gmagick gem to add support' : ''}))
        end
      end

      def draw_image_border top, w, h, alignment
        if (@theme.image_border_width || 0) > 0 && @theme.image_border_color
          if (@theme.image_border_fit || 'content') == 'auto'
            bb_width = bounds.width
          elsif alignment == :center
            bb_x = (bounds.width - w) * 0.5
          elsif alignment == :right
            bb_x = bounds.width - w
          end
          bounding_box [(bb_x || 0), top], width: (bb_width || w), height: h, position: alignment do
            theme_fill_and_stroke_bounds :image, background_color: nil
          end
          true
        end
      end

      def on_image_error _reason, node, target, opts = {}
        logger.warn opts[:message] if (opts.key? :message) && !scratch?
        alt_text_vars = { alt: (node.attr 'alt'), target: target }
        alt_text_template = @theme.image_alt_content || '%{link}[%{alt}]%{/link} | <em>%{target}</em>'
        if (link = node.attr 'link', nil, false)
          alt_text_vars[:link] = %(<a href="#{link}">)
          alt_text_vars[:'/link'] = '</a>'
        else
          alt_text_vars[:link] = ''
          alt_text_vars[:'/link'] = ''
        end
        alt_text = alt_text_template % alt_text_vars
        theme_font :image_alt do
          layout_prose alt_text,
              align: ((node.attr 'align', nil, false) || @theme.image_align).to_sym,
              margin: 0,
              normalize: false,
              single_line: true
        end
        layout_caption node, category: :image, side: :bottom if node.title?
        theme_margin :block, :bottom unless opts[:pinned]
        nil
      end

      def convert_audio node
        add_dest_for_block node if node.id
        theme_margin :block, :top
        audio_path = node.media_uri node.attr 'target'
        play_symbol = (node.document.attr? 'icons', 'font') ? %(<font name="fas">#{(icon_font_data 'fas').unicode 'play'}</font>) : RightPointer
        layout_prose %(#{play_symbol}#{NoBreakSpace}<a href="#{audio_path}">#{audio_path}</a> <em>(audio)</em>), normalize: false, margin: 0, single_line: true
        layout_caption node, side: :bottom if node.title?
        theme_margin :block, :bottom
      end

      def convert_video node
        case (poster = node.attr 'poster', nil, false)
        when 'youtube'
          video_path = %(https://www.youtube.com/watch?v=#{video_id = node.attr 'target'})
          # see http://stackoverflow.com/questions/2068344/how-do-i-get-a-youtube-video-thumbnail-from-the-youtube-api
          poster = allow_uri_read ? %(https://img.youtube.com/vi/#{video_id}/maxresdefault.jpg) : nil
          type = 'YouTube video'
        when 'vimeo'
          video_path = %(https://vimeo.com/#{video_id = node.attr 'target'})
          if allow_uri_read
            poster = load_open_uri.open_uri(%(https://vimeo.com/api/oembed.xml?url=https%3A//vimeo.com/#{video_id}&width=1280), 'r') {|f| (VimeoThumbnailRx.match f.read)[1] } rescue nil
          else
            poster = nil
          end
          type = 'Vimeo video'
        else
          video_path = node.media_uri node.attr 'target'
          type = 'video'
        end

        if poster.nil_or_empty?
          add_dest_for_block node if node.id
          theme_margin :block, :top
          play_symbol = (node.document.attr? 'icons', 'font') ? %(<font name="fas">#{(icon_font_data 'fas').unicode 'play'}</font>) : RightPointer
          layout_prose %(#{play_symbol}#{NoBreakSpace}<a href="#{video_path}">#{video_path}</a> <em>(#{type})</em>), normalize: false, margin: 0, single_line: true
          layout_caption node, side: :bottom if node.title?
          theme_margin :block, :bottom
        else
          original_attributes = node.attributes.dup
          begin
            node.update_attributes 'target' => poster, 'link' => video_path
            #node.set_attr 'pdfwidth', '100%' unless (node.attr? 'width') || (node.attr? 'pdfwidth')
            convert_image node
          ensure
            node.attributes.replace original_attributes
          end
        end
      end

      # QUESTION can we avoid arranging fragments multiple times (conums & autofit) by eagerly preparing arranger?
      def convert_listing_or_literal node
        add_dest_for_block node if node.id

        # HACK: disable built-in syntax highlighter; must be done before calling node.content!
        if node.style == 'source' && (highlighter = @capabilities[:syntax_highlighter] ?
            (syntax_hl = node.document.syntax_highlighter) && syntax_hl.highlight? && syntax_hl.name :
            (highlighter = node.document.attributes['source-highlighter']) && (SourceHighlighters.include? highlighter) && highlighter)
          case highlighter
          when 'coderay'
            unless defined? ::Asciidoctor::Prawn::CodeRayEncoder
              highlighter = nil if (Helpers.require_library CodeRayRequirePath, 'coderay', :warn).nil?
            end
          when 'pygments'
            unless defined? ::Pygments::Ext::BlockStyles
              highlighter = nil if (Helpers.require_library PygmentsRequirePath, 'pygments.rb', :warn).nil?
            end
          when 'rouge'
            unless defined? ::Rouge::Formatters::Prawn
              highlighter = nil if (Helpers.require_library RougeRequirePath, 'rouge', :warn).nil?
            end
          end
          prev_subs = (subs = node.subs).dup
          # NOTE: the highlight sub is only set for coderay, rouge, and pygments atm
          highlight_idx = subs.index :highlight
          # NOTE: scratch? here only applies if listing block is nested inside another block
          if !highlighter || scratch?
            highlighter = nil
            if highlight_idx
              # switch the :highlight sub back to :specialcharacters
              subs[highlight_idx] = :specialcharacters
            else
              prev_subs = nil
            end
            source_string = guard_indentation node.content
          else
            # NOTE: the source highlighter logic below handles the callouts and highlight subs
            if highlight_idx
              subs.delete_all :highlight, :callouts
            else
              subs.delete_all :specialcharacters, :callouts
            end
            # NOTE: indentation guards will be added by the source highlighter logic
            source_string = expand_tabs node.content
          end
        else
          highlighter = nil
          source_string = guard_indentation node.content
        end

        case highlighter
        when 'coderay'
          source_string, conum_mapping = extract_conums source_string
          srclang = node.attr 'language', 'text', false
          begin
            ::CodeRay::Scanners[(srclang = (srclang.start_with? 'html+') ? (srclang.slice 5, srclang.length).to_sym : srclang.to_sym)]
          rescue ::ArgumentError
            srclang = :text
          end
          fragments = (::CodeRay.scan source_string, srclang).to_prawn
          source_chunks = conum_mapping ? (restore_conums fragments, conum_mapping) : fragments
        when 'pygments'
          style = (node.document.attr 'pygments-style') || 'pastie'
          # QUESTION allow border color to be set by theme for highlighted block?
          pg_block_styles = ::Pygments::Ext::BlockStyles.for style
          bg_color_override = pg_block_styles[:background_color]
          font_color_override = pg_block_styles[:font_color]
          if source_string.empty?
            source_chunks = []
          else
            lexer = (::Pygments::Lexer.find_by_alias node.attr 'language', 'text', false) || (::Pygments::Lexer.find_by_mimetype 'text/plain')
            lexer_opts = { nowrap: true, noclasses: true, stripnl: false, style: style }
            lexer_opts[:startinline] = !(node.option? 'mixed') if lexer.name == 'PHP'
            source_string, conum_mapping = extract_conums source_string
            # NOTE: highlight can return nil if something goes wrong; fallback to encoded source string if this happens
            result = (lexer.highlight source_string, options: lexer_opts) || (node.apply_subs source_string, [:specialcharacters])
            if node.attr? 'highlight', nil, false
              if (highlight_lines = (node.method :resolve_lines_to_highlight).arity.abs > 1 ?
                  (node.resolve_lines_to_highlight source_string, (node.attr 'highlight')) :
                  (node.resolve_lines_to_highlight node.attr 'highlight')).empty?
                highlight_lines = nil
              else
                pg_highlight_bg_color = pg_block_styles[:highlight_background_color]
                highlight_lines = highlight_lines.map {|linenum| [linenum, pg_highlight_bg_color] }.to_h
              end
            end
            if node.attr? 'linenums'
              linenums = (node.attr 'start', 1, false).to_i
              @theme.code_linenum_font_color ||= '999999'
              postprocess = true
              wrap_ext = FormattedText::SourceWrap
            elsif conum_mapping || highlight_lines
              postprocess = true
            end
            fragments = text_formatter.format result
            fragments = restore_conums fragments, conum_mapping, linenums, highlight_lines if postprocess
            source_chunks = guard_indentation_in_fragments fragments
          end
        when 'rouge'
          formatter = (@rouge_formatter ||= ::Rouge::Formatters::Prawn.new theme: (node.document.attr 'rouge-style'), line_gap: @theme.code_line_gap, highlight_background_color: @theme.code_highlight_background_color)
          # QUESTION allow border color to be set by theme for highlighted block?
          bg_color_override = formatter.background_color
          if source_string.empty?
            source_chunks = []
          else
            if node.attr? 'linenums'
              formatter_opts = { line_numbers: true, start_line: (node.attr 'start', 1, false).to_i }
              wrap_ext = FormattedText::SourceWrap
            else
              formatter_opts = {}
            end
            if (srclang = node.attr 'language', nil, false)
              if srclang.include? '?'
                if (lexer = ::Rouge::Lexer.find_fancy srclang)
                  unless lexer.tag != 'php' || (node.option? 'mixed') || ((lexer_opts = lexer.options).key? 'start_inline')
                    lexer = lexer.class.new lexer_opts.merge 'start_inline' => true
                  end
                end
              elsif (lexer = ::Rouge::Lexer.find srclang)
                lexer = lexer.new start_inline: true if lexer.tag == 'php' && !(node.option? 'mixed')
              end
            end
            lexer ||= ::Rouge::Lexers::PlainText
            source_string, conum_mapping = extract_conums source_string
            if node.attr? 'highlight', nil, false
              unless (hl_lines = (node.method :resolve_lines_to_highlight).arity.abs > 1 ?
                  (node.resolve_lines_to_highlight source_string, (node.attr 'highlight')) :
                  (node.resolve_lines_to_highlight node.attr 'highlight')).empty?
                formatter_opts[:highlight_lines] = hl_lines.map {|linenum| [linenum, true] }.to_h
              end
            end
            fragments = formatter.format (lexer.lex source_string), formatter_opts
            source_chunks = conum_mapping ? (restore_conums fragments, conum_mapping) : fragments
          end
        else
          # NOTE: only format if we detect a need (callouts or inline formatting)
          source_chunks = (XMLMarkupRx.match? source_string) ? (text_formatter.format source_string) : [text: source_string]
        end

        node.subs.replace prev_subs if prev_subs

        adjusted_font_size = ((node.option? 'autofit') || (node.document.attr? 'autofit-option')) ?
            (theme_font_size_autofit source_chunks, :code) : nil

        theme_margin :block, :top

        keep_together do |box_height = nil|
          caption_height = node.title? ? (layout_caption node, category: :code) : 0
          theme_font :code do
            theme_fill_and_stroke_block :code, (box_height - caption_height), background_color: bg_color_override, split_from_top: false if box_height
            pad_box @theme.code_padding do
              ::Prawn::Text::Formatted::Box.extensions << wrap_ext if wrap_ext
              typeset_formatted_text source_chunks, (calc_line_metrics @theme.code_line_height || @theme.base_line_height),
                  color: (font_color_override || @theme.code_font_color || @font_color),
                  size: adjusted_font_size
              ::Prawn::Text::Formatted::Box.extensions.pop if wrap_ext
            end
          end
        end
        stroke_horizontal_rule @theme.caption_border_bottom_color if node.title? && @theme.caption_border_bottom_color

        theme_margin :block, :bottom
      end

      alias convert_listing convert_listing_or_literal
      alias convert_literal convert_listing_or_literal

      def convert_pass node
        node = node.dup
        (subs = node.subs.dup).unshift :specialcharacters
        node.instance_variable_set :@subs, subs.uniq
        convert_listing_or_literal node
      end

      alias convert_stem convert_listing_or_literal

      # Extract callout marks from string, indexed by 0-based line number
      # Return an Array with the processed string as the first argument
      # and the mapping of lines to conums as the second.
      def extract_conums string
        conum_mapping = {}
        auto_num = 0
        string = string.split(LF).map.with_index {|line, line_num|
          # FIXME: we get extra spaces before numbers if more than one on a line
          if line.include? '<'
            line = line.gsub CalloutExtractRx do
              # honor the escape
              if $1 == ?\\
                $&.sub $1, ''
              else
                (conum_mapping[line_num] ||= []) << ($3 == '.' ? (auto_num += 1) : $3.to_i)
                ''
              end
            end
            # NOTE use first position to store space that precedes conums
            if (conum_mapping.key? line_num) && (line.end_with? ' ')
              trimmed_line = line.rstrip
              conum_mapping[line_num].unshift line.slice trimmed_line.length, line.length
              line = trimmed_line
            end
          end
          line
        }.join LF
        conum_mapping = nil if conum_mapping.empty?
        [string, conum_mapping]
      end

      # Restore the conums into the Array of formatted text fragments
      #--
      # QUESTION can this be done more efficiently?
      # QUESTION can we reuse arrange_fragments_by_line?
      def restore_conums fragments, conum_mapping, linenums = nil, highlight_lines = nil
        lines = []
        line_num = 0
        # reorganize the fragments into an array of lines
        fragments.each do |fragment|
          line = (lines[line_num] ||= [])
          if (text = fragment[:text]) == LF
            lines[line_num += 1] ||= []
          elsif text.include? LF
            text.split(LF, -1).each_with_index do |line_in_fragment, idx|
              line = (lines[line_num += 1] ||= []) unless idx == 0
              line << (fragment.merge text: line_in_fragment) unless line_in_fragment.empty?
            end
          else
            line << fragment
          end
        end
        conum_font_color = @theme.conum_font_color
        if (conum_font_name = @theme.conum_font_family) == font_name
          conum_font_name = nil
        end
        last_line_num = lines.size - 1
        if linenums
          pad_size = (last_line_num + 1).to_s.length
          linenum_color = @theme.code_linenum_font_color
        end
        # append conums to appropriate lines, then flatten to an array of fragments
        lines.flat_map.with_index do |line, cur_line_num|
          last_line = cur_line_num == last_line_num
          visible_line_num = cur_line_num + (linenums || 1)
          if highlight_lines && (highlight_bg_color = highlight_lines[visible_line_num])
            line.unshift text: DummyText, background_color: highlight_bg_color, highlight: true, inline_block: true, extend: true, width: 0, callback: [FormattedText::TextBackgroundAndBorderRenderer]
          end
          line.unshift text: %(#{visible_line_num.to_s.rjust pad_size} ), linenum: visible_line_num, color: linenum_color if linenums
          if conum_mapping && (conums = conum_mapping.delete cur_line_num)
            line << { text: conums.shift } if ::String === conums[0]
            conum_text = conums.map {|num| conum_glyph num }.join ' '
            conum_fragment = { text: conum_text }
            conum_fragment[:color] = conum_font_color if conum_font_color
            conum_fragment[:font] = conum_font_name if conum_font_name
            line << conum_fragment
          end
          line << { text: LF } unless last_line
          line
        end
      end

      def conum_glyph number
        @conum_glyphs[number - 1]
      end

      def convert_table node
        add_dest_for_block node if node.id
        # TODO: we could skip a lot of the logic below when num_rows == 0
        num_rows = node.attr 'rowcount'
        num_cols = node.columns.size
        table_header_size = false
        theme = @theme

        tbl_bg_color = resolve_theme_color :table_background_color
        # QUESTION should we fallback to page background color? (which is never transparent)
        #tbl_bg_color = resolve_theme_color :table_background_color, @page_bg_color
        # ...and if so, should we try to be helpful and use @page_bg_color for tables nested in blocks?
        #unless tbl_bg_color
        #  tbl_bg_color = @page_bg_color unless [:section, :document].include? node.parent.context
        #end

        # NOTE: emulate table bg color by using it as a fallback value for each element
        head_bg_color = resolve_theme_color :table_head_background_color, tbl_bg_color
        foot_bg_color = resolve_theme_color :table_foot_background_color, tbl_bg_color
        body_bg_color = resolve_theme_color :table_body_background_color, tbl_bg_color
        body_stripe_bg_color = resolve_theme_color :table_body_stripe_background_color, tbl_bg_color

        base_header_cell_data = nil
        header_cell_line_metrics = nil

        table_data = []
        theme_font :table do
          head_rows = node.rows[:head]
          body_rows = node.rows[:body]
          #if (hrows = node.attr 'hrows', false, nil) && (shift_rows = hrows.to_i - head_rows.size) > 0
          #  head_rows = head_rows.dup
          #  body_rows = body_rows.dup
          #  shift_rows.times { head_rows << body_rows.shift unless body_rows.empty? }
          #end
          theme_font :table_head do
            table_header_size = head_rows.size
            head_font_info = font_info
            head_line_metrics = calc_line_metrics theme.base_line_height
            head_cell_padding = theme.table_head_cell_padding || theme.table_cell_padding
            head_cell_padding = ::Array === head_cell_padding && head_cell_padding.size == 4 ? head_cell_padding.dup : (inflate_padding head_cell_padding)
            head_cell_padding[0] += head_line_metrics.padding_top
            head_cell_padding[2] += head_line_metrics.padding_bottom
            # QUESTION why doesn't text transform inherit from table?
            head_transform = resolve_text_transform :table_head_text_transform, nil
            base_cell_data = {
              inline_format: [normalize: true],
              background_color: head_bg_color,
              text_color: @font_color,
              size: head_font_info[:size],
              font: head_font_info[:family],
              font_style: head_font_info[:style],
              kerning: default_kerning?,
              padding: head_cell_padding,
              leading: head_line_metrics.leading,
              # TODO: patch prawn-table to pass through final_gap option
              #final_gap: head_line_metrics.final_gap,
            }
            head_rows.each do |row|
              table_data << (row.map do |cell|
                cell_text = head_transform ? (transform_text cell.text.strip, head_transform) : cell.text.strip
                cell_text = hyphenate_text cell_text, @hyphenator if defined? @hyphenator
                base_cell_data.merge \
                  content: cell_text,
                  colspan: cell.colspan || 1,
                  align: (cell.attr 'halign', nil, false).to_sym,
                  valign: (val = cell.attr 'valign', nil, false) == 'middle' ? :center : val.to_sym
              end)
            end
          end unless head_rows.empty?

          base_cell_data = {
            font: (body_font_info = font_info)[:family],
            font_style: body_font_info[:style],
            size: body_font_info[:size],
            kerning: default_kerning?,
            text_color: @font_color,
          }
          body_cell_line_metrics = calc_line_metrics theme.base_line_height
          (body_rows + node.rows[:foot]).each do |row|
            table_data << (row.map do |cell|
              cell_data = base_cell_data.merge \
                colspan: cell.colspan || 1,
                rowspan: cell.rowspan || 1,
                align: (cell.attr 'halign', nil, false).to_sym,
                valign: (val = cell.attr 'valign', nil, false) == 'middle' ? :center : val.to_sym
              cell_line_metrics = body_cell_line_metrics
              case cell.style
              when :emphasis
                cell_data[:font_style] = :italic
              when :strong
                cell_data[:font_style] = :bold
              when :header
                unless base_header_cell_data
                  theme_font :table_head do
                    theme_font :table_header_cell do
                      header_cell_font_info = font_info
                      base_header_cell_data = {
                        text_color: @font_color,
                        font: header_cell_font_info[:family],
                        size: header_cell_font_info[:size],
                        font_style: header_cell_font_info[:style],
                        text_transform: @text_transform,
                      }
                      header_cell_line_metrics = calc_line_metrics theme.base_line_height
                    end
                  end
                  if (val = resolve_theme_color :table_header_cell_background_color, head_bg_color)
                    base_header_cell_data[:background_color] = val
                  end
                end
                cell_data.update base_header_cell_data
                cell_transform = cell_data.delete :text_transform
                cell_line_metrics = header_cell_line_metrics
              when :monospaced
                cell_data.delete :font_style
                theme_font :literal do
                  mono_cell_font_info = font_info
                  cell_data[:font] = mono_cell_font_info[:family]
                  cell_data[:size] = mono_cell_font_info[:size]
                  cell_data[:text_color] = @font_color
                  cell_line_metrics = calc_line_metrics theme.base_line_height
                end
              when :literal
                # NOTE: we want the raw AsciiDoc in this case
                cell_data[:content] = guard_indentation cell.instance_variable_get :@text
                # NOTE: the absence of the inline_format option implies it's disabled
                cell_data.delete :font_style
                # QUESTION should we use literal_font_*, code_font_*, or introduce another category?
                theme_font :code do
                  literal_cell_font_info = font_info
                  cell_data[:font] = literal_cell_font_info[:family]
                  cell_data[:size] = literal_cell_font_info[:size]
                  cell_data[:text_color] = @font_color
                  cell_line_metrics = calc_line_metrics theme.base_line_height
                end
              when :verse
                cell_data[:content] = guard_indentation cell.text
                cell_data[:inline_format] = true
                cell_data.delete :font_style
              when :asciidoc
                cell_data.delete :kerning
                cell_data.delete :font_style
                cell_line_metrics = nil
                asciidoc_cell = ::Prawn::Table::Cell::AsciiDoc.new self,
                    (cell_data.merge content: cell.inner_document, font_style: (val = theme.table_font_style) ? val.to_sym : nil, padding: theme.table_cell_padding)
                cell_data = { content: asciidoc_cell }
              end
              if cell_line_metrics
                cell_padding = ::Array === (cell_padding = theme.table_cell_padding) && cell_padding.size == 4 ?
                  cell_padding.dup : (inflate_padding cell_padding)
                cell_padding[0] += cell_line_metrics.padding_top
                cell_padding[2] += cell_line_metrics.padding_bottom
                cell_data[:leading] = cell_line_metrics.leading
                # TODO: patch prawn-table to pass through final_gap option
                #cell_data[:final_gap] = cell_line_metrics.final_gap
                cell_data[:padding] = cell_padding
              end
              unless cell_data.key? :content
                cell_text = cell.text.strip
                cell_text = transform_text cell_text, cell_transform if cell_transform
                cell_text = hyphenate_text cell_text, @hyphenator if defined? @hyphenator
                cell_text = cell_text.gsub CjkLineBreakRx, ZeroWidthSpace if @cjk_line_breaks
                if cell_text.include? LF
                  # NOTE: effectively the same as calling cell.content (should we use that instead?)
                  # FIXME: hard breaks not quite the same result as separate paragraphs; need custom cell impl here
                  cell_data[:content] = (cell_text.split BlankLineRx).map {|l| l.tr_s WhitespaceChars, ' ' }.join DoubleLF
                  cell_data[:inline_format] = true
                else
                  cell_data[:content] = cell_text
                  cell_data[:inline_format] = [normalize: true]
                end
              end
              if node.document.attr? 'cellbgcolor'
                if (cell_bg_color = node.document.attr 'cellbgcolor') == 'transparent'
                  cell_data[:background_color] = body_bg_color
                elsif (cell_bg_color.start_with? '#') && (HexColorRx.match? cell_bg_color)
                  cell_data[:background_color] = cell_bg_color.slice 1, cell_bg_color.length
                end
              end
              cell_data
            end)
          end
        end

        # NOTE: Prawn aborts if table data is empty, so ensure there's at least one row
        if table_data.empty?
          logger.warn message_with_context 'no rows found in table', source_location: node.source_location
          table_data << ::Array.new([node.columns.size, 1].max) { { content: '' } }
        end

        border_width = {}
        table_border_color = theme.table_border_color || theme.table_grid_color || theme.base_border_color
        table_border_style = (theme.table_border_style || :solid).to_sym
        table_border_width = theme.table_border_width
        if table_header_size
          head_border_bottom_color = theme.table_head_border_bottom_color || table_border_color
          head_border_bottom_style = (theme.table_head_border_bottom_style || table_border_style).to_sym
          head_border_bottom_width = theme.table_head_border_bottom_width || table_border_width
        end
        [:top, :bottom, :left, :right].each {|edge| border_width[edge] = table_border_width }
        table_grid_color = theme.table_grid_color || table_border_color
        table_grid_style = (theme.table_grid_style || table_border_style).to_sym
        table_grid_width = theme.table_grid_width || theme.table_border_width
        [:cols, :rows].each {|edge| border_width[edge] = table_grid_width }

        case (grid = node.attr 'grid', 'all', 'table-grid')
        when 'all'
          # keep inner borders
        when 'cols'
          border_width[:rows] = 0
        when 'rows'
          border_width[:cols] = 0
        else # none
          border_width[:rows] = border_width[:cols] = 0
        end

        case (frame = node.attr 'frame', 'all', 'table-frame')
        when 'all'
          # keep outer borders
        when 'topbot', 'ends'
          border_width[:left] = border_width[:right] = 0
        when 'sides'
          border_width[:top] = border_width[:bottom] = 0
        else # none
          border_width[:top] = border_width[:right] = border_width[:bottom] = border_width[:left] = 0
        end

        if node.option? 'autowidth'
          table_width = (node.attr? 'width', nil, false) ? bounds.width * ((node.attr 'tablepcwidth') / 100.0) :
              (((node.has_role? 'stretch') || (node.has_role? 'spread')) ? bounds.width : nil)
          column_widths = []
        else
          table_width = bounds.width * ((node.attr 'tablepcwidth') / 100.0)
          column_widths = node.columns.map {|col| ((col.attr 'colpcwidth') * table_width) / 100.0 }
          # NOTE: until Asciidoctor 1.5.4, colpcwidth values didn't always add up to 100%; use last column to compensate
          unless column_widths.empty? || (width_delta = table_width - column_widths.sum) == 0
            column_widths[-1] += width_delta
          end
        end

        if ((alignment = node.attr 'align', nil, false) && (BlockAlignmentNames.include? alignment)) ||
            (alignment = (node.roles & BlockAlignmentNames)[-1])
          alignment = alignment.to_sym
        else
          alignment = (theme.table_align || :left).to_sym
        end

        caption_side = (theme.table_caption_side || :top).to_sym
        caption_max_width = theme.table_caption_max_width || 'fit-content'

        table_settings = {
          header: table_header_size,
          # NOTE: position is handled by this method
          position: :left,
          cell_style: {
            # NOTE: the border color and style of the outer frame is set later
            border_color: table_grid_color,
            border_lines: [table_grid_style],
            # NOTE: the border width is set later
            border_width: 0,
          },
          width: table_width,
          column_widths: column_widths,
        }

        # QUESTION should we support nth; should we support sequence of roles?
        case node.attr 'stripes', nil, 'table-stripes'
        when 'all'
          table_settings[:row_colors] = [body_stripe_bg_color]
        when 'even'
          table_settings[:row_colors] = [body_bg_color, body_stripe_bg_color]
        when 'odd'
          table_settings[:row_colors] = [body_stripe_bg_color, body_bg_color]
        else # none
          table_settings[:row_colors] = [body_bg_color]
        end

        theme_margin :block, :top

        left_padding = right_padding = nil
        table table_data, table_settings do
          # NOTE: call width to capture resolved table width
          table_width = width
          @pdf.layout_table_caption node, alignment, table_width, caption_max_width if node.title? && caption_side == :top
          # NOTE align using padding instead of bounding_box as prawn-table does
          # using a bounding_box across pages mangles the margin box of subsequent pages
          if alignment != :left && table_width != (this_bounds = @pdf.bounds).width
            if alignment == :center
              left_padding = right_padding = (this_bounds.width - width) * 0.5
              this_bounds.add_left_padding left_padding
              this_bounds.add_right_padding right_padding
            else # :right
              left_padding = this_bounds.width - width
              this_bounds.add_left_padding left_padding
            end
          end
          if grid == 'none' && frame == 'none'
            rows(table_header_size).tap do |r|
              r.border_bottom_color = head_border_bottom_color
              r.border_bottom_line = head_border_bottom_style
              r.border_bottom_width = head_border_bottom_width
            end if table_header_size
          else
            # apply the grid setting first across all cells
            cells.border_width = [border_width[:rows], border_width[:cols], border_width[:rows], border_width[:cols]]

            if table_header_size
              rows(table_header_size - 1).tap do |r|
                r.border_bottom_color = head_border_bottom_color
                r.border_bottom_line = head_border_bottom_style
                r.border_bottom_width = head_border_bottom_width
              end
              rows(table_header_size).tap do |r|
                r.border_top_color = head_border_bottom_color
                r.border_top_line = head_border_bottom_style
                r.border_top_width = head_border_bottom_width
              end if num_rows > table_header_size
            end

            # top edge of table
            rows(0).tap do |r|
              r.border_top_color, r.border_top_line, r.border_top_width = table_border_color, table_border_style, border_width[:top]
            end
            # right edge of table
            columns(num_cols - 1).tap do |r|
              r.border_right_color, r.border_right_line, r.border_right_width = table_border_color, table_border_style, border_width[:right]
            end
            # bottom edge of table
            rows(num_rows - 1).tap do |r|
              r.border_bottom_color, r.border_bottom_line, r.border_bottom_width = table_border_color, table_border_style, border_width[:bottom]
            end
            # left edge of table
            columns(0).tap do |r|
              r.border_left_color, r.border_left_line, r.border_left_width = table_border_color, table_border_style, border_width[:left]
            end
          end

          # QUESTION should cell padding be configurable for foot row cells?
          unless node.rows[:foot].empty?
            foot_row = row num_rows.pred
            foot_row.background_color = foot_bg_color
            # FIXME: find a way to do this when defining the cells
            foot_row.text_color = theme.table_foot_font_color if theme.table_foot_font_color
            foot_row.size = theme.table_foot_font_size if theme.table_foot_font_size
            foot_row.font = theme.table_foot_font_family if theme.table_foot_font_family
            foot_row.font_style = theme.table_foot_font_style.to_sym if theme.table_foot_font_style
            # HACK: we should do this transformation when creating the cell
            #if (foot_transform = resolve_text_transform :table_foot_text_transform, nil)
            #  foot_row.each {|c| c.content = (transform_text c.content, foot_transform) if c.content }
            #end
          end
        end
        if left_padding
          bounds.subtract_left_padding left_padding
          bounds.subtract_right_padding right_padding if right_padding
        end
        layout_table_caption node, alignment, table_width, caption_max_width, caption_side if node.title? && caption_side == :bottom
        theme_margin :block, :bottom
      end

      def convert_thematic_break _node
        theme_margin :thematic_break, :top
        stroke_horizontal_rule @theme.thematic_break_border_color, line_width: @theme.thematic_break_border_width, line_style: @theme.thematic_break_border_style.to_sym
        theme_margin :thematic_break, :bottom
      end

      # deprecated
      alias convert_horizontal_rule convert_thematic_break

      def convert_toc node
        if ((doc = node.document).attr? 'toc-placement', 'macro') && doc.sections?
          if (is_book = doc.doctype == 'book')
            start_new_page unless at_page_top?
            start_new_page if @ppbook && verso_page? && !(node.option? 'nonfacing')
          end
          add_dest_for_block node, (derive_anchor_from_id node.id, 'toc')
          allocate_toc doc, (doc.attr 'toclevels', 2).to_i, @y, (is_book || (doc.attr? 'title-page'))
        end
        nil
      end

      # NOTE to insert sequential page breaks, you must put {nbsp} between page breaks
      def convert_page_break node
        if (page_layout = node.attr 'page-layout').nil_or_empty?
          unless node.role? && (page_layout = (node.roles.map(&:to_sym) & PageLayouts)[-1])
            page_layout = nil
          end
        elsif !PageLayouts.include?(page_layout = page_layout.to_sym)
          page_layout = nil
        end

        if at_page_top?
          if page_layout && page_layout != page.layout && page.empty?
            delete_page
            advance_page layout: page_layout
          end
        elsif page_layout
          advance_page layout: page_layout
        else
          advance_page
        end
      end

      def convert_index_section _node
        unless @index.empty?
          space_needed_for_category = @theme.description_list_term_spacing + (2 * (height_of_typeset_text 'A'))
          column_box [0, cursor], columns: 2, width: bounds.width, reflow_margins: true do
            @index.categories.each do |category|
              # NOTE cursor method always returns 0 inside column_box; breaks reference_bounds.move_past_bottom
              bounds.move_past_bottom if space_needed_for_category > y - reference_bounds.absolute_bottom
              layout_prose category.name,
                  align: :left,
                  inline_format: false,
                  margin_top: 0,
                  margin_bottom: @theme.description_list_term_spacing,
                  style: @theme.description_list_term_font_style.to_sym
              category.terms.each do |term|
                convert_index_list_item term
              end
              if @theme.prose_margin_bottom > y - reference_bounds.absolute_bottom
                bounds.move_past_bottom
              else
                move_down @theme.prose_margin_bottom
              end
            end
          end
        end
        nil
      end

      def convert_index_list_item term
        text = escape_xml term.name
        unless term.container?
          if @media == 'screen'
            pagenums = term.dests.map {|dest| %(<a anchor="#{dest[:anchor]}">#{dest[:page]}</a>) }
          else
            pagenums = consolidate_ranges term.dests.uniq {|dest| dest[:page] }.map {|dest| dest[:page].to_s }
          end
          text = %(#{text}, #{pagenums.join ', '})
        end
        subterm_indent = @theme.description_list_description_indent
        layout_prose text, align: :left, margin: 0, normalize_line_height: true, hanging_indent: subterm_indent * 2
        indent subterm_indent do
          term.subterms.each do |subterm|
            convert_index_list_item subterm
          end
        end unless term.leaf?
      end

      def convert_inline_anchor node
        doc = node.document
        target = node.target
        case node.type
        when :link
          attrs = []
          #attrs << %( id="#{node.id}") if node.id
          if (role = node.role)
            attrs << %( class="#{role}")
          end
          #attrs << %( title="#{node.attr 'title'}") if node.attr? 'title'
          attrs << %( target="#{node.attr 'window'}") if node.attr? 'window', nil, false
          if (@media ||= doc.attr 'media', 'screen') != 'screen' && (target.start_with? 'mailto:') && (doc.attr? 'hide-uri-scheme')
            bare_target = target.slice 7, target.length
            node.add_role 'bare' if (text = node.text) == bare_target
          else
            bare_target = target
            text = node.text
          end
          if (role = node.attr 'role', nil, false) && (role == 'bare' || ((role.split ' ').include? 'bare'))
            # QUESTION should we insert breakable chars into URI when building fragment instead?
            %(<a href="#{target}"#{attrs.join}>#{breakable_uri text}</a>)
          # NOTE @media may not be initialized if method is called before convert phase
          elsif @media != 'screen' || (doc.attr? 'show-link-uri')
            # QUESTION should we insert breakable chars into URI when building fragment instead?
            # TODO: allow style of printed link to be controlled by theme
            %(<a href="#{target}"#{attrs.join}>#{text}</a> [<font size="0.85em">#{breakable_uri bare_target}</font>&#93;)
          else
            %(<a href="#{target}"#{attrs.join}>#{text}</a>)
          end
        when :xref
          # NOTE non-nil path indicates this is an inter-document xref that's not included in current document
          if (path = node.attributes['path'])
            # NOTE we don't use local as that doesn't work on the web
            # NOTE for the fragment to work in most viewers, it must be #page=<N> <= document this!
            %(<a href="#{target}">#{node.text || path}</a>)
          elsif (refid = node.attributes['refid'])
            unless (text = node.text)
              if (refs = doc.catalog[:refs])
                if ::Asciidoctor::AbstractNode === (ref = refs[refid])
                  text = ref.xreftext node.attr 'xrefstyle', nil, true
                end
              else
                # Asciidoctor < 1.5.6
                text = doc.catalog[:ids][refid]
              end
            end
            %(<a anchor="#{derive_anchor_from_id refid}">#{text || "[#{refid}]"}</a>).gsub ']', '&#93;'
          else
            %(<a anchor="#{doc.attr 'pdf-anchor'}">#{node.text || '[^top&#93;'}</a>)
          end
        when :ref
          # NOTE destination is created inside callback registered by FormattedTextTransform#build_fragment
          # NOTE id is used instead of target starting in Asciidoctor 2.0.0
          %(<a id="#{target || node.id}">#{DummyText}</a>)
        when :bibref
          # NOTE destination is created inside callback registered by FormattedTextTransform#build_fragment
          # NOTE technically node.text should be node.reftext, but subs have already been applied to text
          # NOTE reftext is no longer enclosed in [] starting in Asciidoctor 2.0.0
          # NOTE id is used instead of target starting in Asciidoctor 2.0.0
          if (reftext = node.reftext)
            reftext = %([#{reftext}]) unless reftext.start_with? '['
          else
            reftext = %([#{target || node.id}])
          end
          %(<a id="#{target || node.id}">#{DummyText}</a>#{reftext})
        else
          logger.warn %(unknown anchor type: #{node.type.inspect}) unless scratch?
        end
      end

      def convert_inline_break node
        %(#{node.text}<br>)
      end

      def convert_inline_button node
        %(<button>#{((load_theme node.document).button_content || '%s').sub '%s', node.text}</button>)
      end

      def convert_inline_callout node
        if (conum_font_family = @theme.conum_font_family) != font_name
          result = %(<font name="#{conum_font_family}">#{conum_glyph node.text.to_i}</font>)
        else
          result = conum_glyph node.text.to_i
        end
        if (conum_font_color = @theme.conum_font_color)
          # NOTE CMYK value gets flattened here, but is restored by formatted text parser
          result = %(<color rgb="#{conum_font_color}">#{result}</font>)
        end
        result
      end

      def convert_inline_footnote node
        if (index = node.attr 'index') && (node.document.footnotes.find {|fn| fn.index == index })
          anchor = node.type == :xref ? '' : %(<a id="_footnoteref_#{index}">#{DummyText}</a>)
          %(#{anchor}<sup>[<a anchor="_footnotedef_#{index}">#{index}</a>]</sup>)
        elsif node.type == :xref
          # NOTE footnote reference not found
          %( <color rgb="FF0000">[#{node.text}]</color>)
        end
      end

      def convert_inline_icon node
        if node.document.attr? 'icons', 'font'
          if (icon_name = node.target).include? '@'
            icon_name, icon_set = icon_name.split '@', 2
            explicit_icon_set = true
          elsif (icon_set = node.attr 'set', nil, false)
            explicit_icon_set = true
          else
            icon_set = node.document.attr 'icon-set', 'fa'
          end
          if icon_set == 'fa' || !(IconSets.include? icon_set)
            icon_set = 'fa'
            # legacy name from Font Awesome < 5
            if (remapped_icon_name = resolve_legacy_icon_name icon_name)
              requested_icon_name = icon_name
              icon_set, icon_name = remapped_icon_name.split '-', 2
              glyph = (icon_font_data icon_set).unicode icon_name
              logger.info { %(#{requested_icon_name} icon found in deprecated fa icon set; using #{icon_name} from #{icon_set} icon set instead) } unless scratch?
            # new name in Font Awesome >= 5 (but document is configured to use fa icon set)
            else
              font_data = nil
              if (resolved_icon_set = FontAwesomeIconSets.find {|candidate| (font_data = icon_font_data candidate).unicode icon_name rescue nil })
                icon_set = resolved_icon_set
                glyph = font_data.unicode icon_name
                logger.info { %(#{icon_name} icon not found in deprecated fa icon set; using match found in #{resolved_icon_set} icon set instead) } unless scratch?
              end
            end
          else
            glyph = (icon_font_data icon_set).unicode icon_name rescue nil
          end
          unless glyph || explicit_icon_set || !icon_name.start_with?(*IconSetPrefixes)
            icon_set, icon_name = icon_name.split '-', 2
            glyph = (icon_font_data icon_set).unicode icon_name rescue nil
          end
          if glyph
            if node.attr? 'size', nil, false
              case (size = node.attr 'size')
              when 'lg'
                size_attr = ' size="1.333em"'
              when 'fw'
                size_attr = ' width="1em"'
              else
                size_attr = %( size="#{size.sub 'x', 'em'}")
              end
            else
              size_attr = ''
            end
            class_attr = node.role? ? %( class="#{node.role}") : ''
            # TODO: support rotate and flip attributes
            %(<font name="#{icon_set}"#{size_attr}#{class_attr}>#{glyph}</font>)
          else
            logger.warn %(#{icon_name} is not a valid icon name in the #{icon_set} icon set) unless scratch?
            %([#{node.attr 'alt'}])
          end
        else
          %([#{node.attr 'alt'}])
        end
      end

      def convert_inline_image node
        if node.type == 'icon'
          convert_inline_icon node
        else
          node.extend ::Asciidoctor::Image unless ::Asciidoctor::Image === node
          target, image_format = node.target_and_format
          if image_format == 'gif' && !(defined? ::GMagick::Image)
            logger.warn %(GIF image format not supported. Install the prawn-gmagick gem or convert #{target} to PNG.) unless scratch?
            img = %([#{node.attr 'alt'}])
          # NOTE an image with a data URI is handled using a temporary file
          elsif (image_path = resolve_image_path node, target, true, image_format)
            if ::File.readable? image_path
              width_attr = (width = preresolve_explicit_width node.attributes) ? %( width="#{width}") : ''
              fit_attr = (fit = node.attr 'fit', nil, false) ? %( fit="#{fit}") : ''
              img = %(<img src="#{image_path}" format="#{image_format}" alt="#{encode_quotes node.attr 'alt'}"#{width_attr}#{fit_attr}>)
            else
              logger.warn %(image to embed not found or not readable: #{image_path}) unless scratch?
              img = %([#{node.attr 'alt'}])
            end
          else
            img = %([#{node.attr 'alt'}])
          end
          (node.attr? 'link', nil, false) ? %(<a href="#{node.attr 'link'}">#{img}</a>) : img
        end
      end

      def convert_inline_indexterm node
        # NOTE indexterms not supported if text gets substituted before PDF is initialized
        if !(defined? @index)
          ''
        elsif scratch?
          node.type == :visible ? node.text : ''
        else
          # NOTE page number (:page key) is added by InlineDestinationMarker
          dest = { anchor: (anchor_name = @index.next_anchor_name) }
          anchor = %(<a id="#{anchor_name}" type="indexterm">#{DummyText}</a>)
          if node.type == :visible
            visible_term = node.text
            @index.store_primary_term (sanitize visible_term), dest
            %(#{anchor}#{visible_term})
          else
            @index.store_term((node.attr 'terms').map {|term| sanitize term }, dest)
            anchor
          end
        end
      end

      def convert_inline_kbd node
        if (keys = node.attr 'keys').size == 1
          %(<key>#{keys[0]}</key>)
        else
          keys.map {|key| %(<key>#{key}</key>) }.join (load_theme node.document).key_separator || '+'
        end
      end

      def convert_inline_menu node
        menu = node.attr 'menu'
        caret = (load_theme node.document).menu_caret_content || %( \u203a )
        if !(submenus = node.attr 'submenus').empty?
          %(<strong>#{[menu, *submenus, (node.attr 'menuitem')].join caret}</strong>)
        elsif (menuitem = node.attr 'menuitem')
          %(<strong>#{menu}#{caret}#{menuitem}</strong>)
        else
          %(<strong>#{menu}</strong>)
        end
      end

      def convert_inline_quoted node
        case node.type
        when :emphasis
          open, close, is_tag = ['<em>', '</em>', true]
        when :strong
          open, close, is_tag = ['<strong>', '</strong>', true]
        when :monospaced, :asciimath, :latexmath
          open, close, is_tag = ['<code>', '</code>', true]
        when :superscript
          open, close, is_tag = ['<sup>', '</sup>', true]
        when :subscript
          open, close, is_tag = ['<sub>', '</sub>', true]
        when :double
          open, close, is_tag = ['&#8220;', '&#8221;', false]
        when :single
          open, close, is_tag = ['&#8216;', '&#8217;', false]
        when :mark
          open, close, is_tag = ['<mark>', '</mark>', true]
        else
          open, close, is_tag = [nil, nil, false]
        end

        inner_text = node.text

        if (role = node.role)
          if (text_transform = (load_theme node.document)[%(role_#{role}_text_transform)])
            inner_text = transform_text inner_text, text_transform
          end
          quoted_text = is_tag ? %(#{open.chop} class="#{role}">#{inner_text}#{close}) : %(<span class="#{role}">#{open}#{inner_text}#{close}</span>)
        else
          quoted_text = %(#{open}#{inner_text}#{close})
        end

        # NOTE destination is created inside callback registered by FormattedTextTransform#build_fragment
        node.id ? %(<a id="#{node.id}">#{DummyText}</a>#{quoted_text}) : quoted_text
      end

      def layout_title_page doc
        return unless doc.header? && !doc.notitle

        # NOTE a new page may have already been started at this point, so decide what to do with it
        if page.empty?
          page.reset_content if (recycle = @ppbook ? recto_page? : true)
        elsif @ppbook && page_number > 0 && recto_page?
          start_new_page
        end

        side = recycle ? page_side : (page_side page_number + 1)
        prev_bg_image = @page_bg_image[side]
        prev_bg_color = @page_bg_color
        if (bg_image = resolve_background_image doc, @theme, 'title-page-background-image')
          @page_bg_image[side] = bg_image[0] && bg_image
        end
        if (bg_color = resolve_theme_color :title_page_background_color)
          @page_bg_color = bg_color
        end
        recycle ? (init_page self) : start_new_page
        @page_bg_image[side] = prev_bg_image if bg_image
        @page_bg_color = prev_bg_color if bg_color

        # IMPORTANT this is the first page created, so we need to set the base font
        font @theme.base_font_family, size: @root_font_size

        # QUESTION allow alignment per element on title page?
        title_align = (@theme.title_page_align || @base_align).to_sym

        # FIXME: disallow .pdf as image type
        if @theme.title_page_logo_display != 'none' && (logo_image_path = (doc.attr 'title-logo-image') || (logo_image_from_theme = @theme.title_page_logo_image))
          if (logo_image_path.include? ':') && logo_image_path =~ ImageAttributeValueRx
            logo_image_attrs = (AttributeList.new $2).parse %w(alt width height)
            if logo_image_from_theme
              relative_to_imagesdir = false
              logo_image_path = sub_attributes_discretely doc, $1
              logo_image_path = ThemeLoader.resolve_theme_asset logo_image_path, @themesdir unless doc.is_uri? logo_image_path
            else
              relative_to_imagesdir = true
              logo_image_path = $1
            end
          else
            logo_image_attrs = {}
            relative_to_imagesdir = false
            if logo_image_from_theme
              logo_image_path = sub_attributes_discretely doc, logo_image_path
              logo_image_path = ThemeLoader.resolve_theme_asset logo_image_path, @themesdir unless doc.is_uri? logo_image_path
            end
          end
          logo_image_attrs['target'] = logo_image_path
          if (logo_align = [(logo_image_attrs.delete 'align'), @theme.title_page_logo_align, title_align.to_s].find {|val| (BlockAlignmentNames.include? val) })
            logo_image_attrs['align'] = logo_align
          end
          if (logo_image_top = logo_image_attrs['top'] || @theme.title_page_logo_top)
            initial_y, @y = @y, (resolve_top logo_image_top)
          end
          # FIXME: add API to Asciidoctor for creating blocks like this (extract from extensions module?)
          image_block = ::Asciidoctor::Block.new doc, :image, content_model: :empty, attributes: logo_image_attrs
          # NOTE pinned option keeps image on same page
          indent (@theme.title_page_logo_margin_left || 0), (@theme.title_page_logo_margin_right || 0) do
            convert_image image_block, relative_to_imagesdir: relative_to_imagesdir, pinned: true
          end
          @y = initial_y if initial_y
        end

        # TODO: prevent content from spilling to next page
        theme_font :title_page do
          if (title_top = @theme.title_page_title_top)
            @y = resolve_top title_top
          end
          unless @theme.title_page_title_display == 'none'
            doctitle = doc.doctitle partition: true
            move_down(@theme.title_page_title_margin_top || 0)
            indent (@theme.title_page_title_margin_left || 0), (@theme.title_page_title_margin_right || 0) do
              theme_font :title_page_title do
                layout_prose doctitle.main,
                    align: title_align,
                    margin: 0,
                    line_height: @theme.title_page_title_line_height
              end
            end
            move_down(@theme.title_page_title_margin_bottom || 0)
          end
          if @theme.title_page_subtitle_display != 'none' && (subtitle = (doctitle || (doc.doctitle partition: true)).subtitle)
            move_down(@theme.title_page_subtitle_margin_top || 0)
            indent (@theme.title_page_subtitle_margin_left || 0), (@theme.title_page_subtitle_margin_right || 0) do
              theme_font :title_page_subtitle do
                layout_prose subtitle,
                    align: title_align,
                    margin: 0,
                    line_height: @theme.title_page_subtitle_line_height
              end
            end
            move_down(@theme.title_page_subtitle_margin_bottom || 0)
          end
          if @theme.title_page_authors_display != 'none' && (doc.attr? 'authors')
            move_down(@theme.title_page_authors_margin_top || 0)
            indent (@theme.title_page_authors_margin_left || 0), (@theme.title_page_authors_margin_right || 0) do
              authors_content = @theme.title_page_authors_content
              authors_content = {
                name_only: @theme.title_page_authors_content_name_only || authors_content,
                with_email: @theme.title_page_authors_content_with_email || authors_content,
                with_url: @theme.title_page_authors_content_with_url || authors_content,
              }
              # TODO: provide an API in core to get authors as an array
              authors = (1..(doc.attr 'authorcount', 1).to_i).map {|idx|
                promote_author doc, idx do
                  author_content_key = (url = doc.attr 'url') ? ((url.start_with? 'mailto:') ? :with_email : :with_url) : :name_only
                  if (author_content = authors_content[author_content_key])
                    apply_subs_discretely doc, author_content
                  else
                    doc.attr 'author'
                  end
                end
              }.join (@theme.title_page_authors_delimiter || ', ')
              theme_font :title_page_authors do
                layout_prose authors,
                    align: title_align,
                    margin: 0,
                    normalize: false
              end
            end
            move_down(@theme.title_page_authors_margin_bottom || 0)
          end
          unless @theme.title_page_revision_display == 'none' || (revision_info = [(doc.attr? 'revnumber') ? %(#{doc.attr 'version-label'} #{doc.attr 'revnumber'}) : nil, (doc.attr 'revdate')].compact).empty?
            move_down(@theme.title_page_revision_margin_top || 0)
            revision_text = revision_info.join (@theme.title_page_revision_delimiter || ', ')
            if (revremark = doc.attr 'revremark')
              revision_text = %(#{revision_text}: #{revremark})
            end
            indent (@theme.title_page_revision_margin_left || 0), (@theme.title_page_revision_margin_right || 0) do
              theme_font :title_page_revision do
                layout_prose revision_text,
                    align: title_align,
                    margin: 0,
                    normalize: false
              end
            end
            move_down(@theme.title_page_revision_margin_bottom || 0)
          end
        end

        layout_prose DummyText, margin: 0, line_height: 1, normalize: false if page.empty?
      end

      def layout_cover_page doc, face
        # TODO: turn processing of attribute with inline image a utility function in Asciidoctor
        if (image_path = (doc.attr %(#{face}-cover-image)))
          if image_path.empty?
            go_to_page page_count if face == :back
            start_new_page_discretely
            # NOTE open graphics state to prevent page from being reused
            open_graphics_state if face == :front
            return
          elsif image_path == '~'
            image_path = nil
            @page_margin_by_side[:cover] = @page_margin_by_side[:recto] if @media == 'prepress'
          elsif (image_path.include? ':') && image_path =~ ImageAttributeValueRx
            image_attrs = (AttributeList.new $2).parse %w(alt width)
            image_path = resolve_image_path doc, $1, true, (image_format = image_attrs['format'])
          else
            image_path = resolve_image_path doc, image_path, false
          end

          return unless image_path

          unless ::File.readable? image_path
            logger.warn %(#{face} cover image not found or readable: #{image_path})
            return
          end

          go_to_page page_count if face == :back
          if image_path.downcase.end_with? '.pdf'
            import_page image_path, page: [((image_attrs || {})['page']).to_i, 1].max, advance: face != :back
          else
            image_opts = resolve_image_options image_path, image_attrs, background: true, format: image_format
            image_page image_path, (image_opts.merge canvas: true)
          end
        end
      end

      def stamp_foreground_image doc, has_front_cover
        pages = state.pages
        if (first_page = (has_front_cover ? (pages.slice 1, pages.size) : pages).find {|it| !it.imported_page? }) &&
            (first_page_num = (pages.index first_page) + 1) &&
            (fg_image = resolve_background_image doc, @theme, 'page-foreground-image') && fg_image[0]
          go_to_page first_page_num
          create_stamp 'foreground-image' do
            canvas { image fg_image[0], ({ position: :center, vposition: :center }.merge fg_image[1]) }
          end
          stamp 'foreground-image'
          (first_page_num.next..page_count).each do |num|
            go_to_page num
            stamp 'foreground-image' unless page.imported_page?
          end
        end
      end

      def start_new_chapter chapter
        start_new_page unless at_page_top?
        # TODO: must call update_colors before advancing to next page if start_new_page is called in layout_chapter_title
        start_new_page if @ppbook && verso_page? && !(chapter.option? 'nonfacing')
      end

      alias start_new_part start_new_chapter

      def layout_chapter_title _node, title, opts = {}
        layout_heading title, (opts.merge outdent: true)
      end

      alias layout_part_title layout_chapter_title

      # NOTE layout_heading doesn't set the theme font because it's used for various types of headings
      # QUESTION why doesn't layout_heading accept a node?
      def layout_heading string, opts = {}
        hlevel = opts[:level]
        unless (top_margin = (margin = (opts.delete :margin)) || (opts.delete :margin_top))
          if at_page_top?
            if hlevel && (top_margin = @theme[%(heading_h#{hlevel}_margin_page_top)] || @theme.heading_margin_page_top || 0) > 0
              move_down top_margin
            end
            top_margin = 0
          else
            top_margin = (hlevel ? @theme[%(heading_h#{hlevel}_margin_top)] : nil) || @theme.heading_margin_top
          end
        end
        bot_margin = margin || (opts.delete :margin_bottom) || (hlevel ? @theme[%(heading_h#{hlevel}_margin_bottom)] : nil) || @theme.heading_margin_bottom
        if (transform = resolve_text_transform opts)
          string = transform_text string, transform
        end
        outdent_section opts.delete :outdent do
          margin_top top_margin
          # QUESTION should we move inherited styles to typeset_text?
          if (inherited = apply_text_decoration ::Set.new, :heading, hlevel).empty?
            inline_format_opts = true
          else
            inline_format_opts = [{ inherited: inherited }]
          end
          typeset_text string, calc_line_metrics((opts.delete :line_height) || (hlevel ? @theme[%(heading_h#{hlevel}_line_height)] : nil) || @theme.heading_line_height || @theme.base_line_height), {
            color: @font_color,
            inline_format: inline_format_opts,
            align: @base_align.to_sym,
          }.merge(opts)
          margin_bottom bot_margin
        end
      end

      # NOTE inline_format is true by default
      def layout_prose string, opts = {}
        top_margin = (margin = (opts.delete :margin)) || (opts.delete :margin_top) || @theme.prose_margin_top
        bot_margin = margin || (opts.delete :margin_bottom) || @theme.prose_margin_bottom
        if (transform = resolve_text_transform opts)
          string = transform_text string, transform
        end
        string = hyphenate_text string, @hyphenator if (opts.delete :hyphenate) && (defined? @hyphenator)
        # NOTE used by extensions; ensures linked text gets formatted using the link styles
        if (anchor = opts.delete :anchor)
          string = %(<a anchor="#{anchor}">#{string}</a>)
        end
        margin_top top_margin
        string = ZeroWidthSpace + string if opts.delete :normalize_line_height
        # NOTE normalize makes endlines soft (replaces "\n" with ' ')
        inline_format_opts = { normalize: (opts.delete :normalize) != false }
        if (styles = opts.delete :styles)
          inline_format_opts[:inherited] = { styles: styles }
        end
        typeset_text string, calc_line_metrics((opts.delete :line_height) || @theme.base_line_height), {
          color: @font_color,
          inline_format: [inline_format_opts],
          align: @base_align.to_sym,
        }.merge(opts)
        margin_bottom bot_margin
      end

      def generate_manname_section node
        title = node.attr 'manname-title', 'Name'
        if (next_section = node.sections[0]) && (next_section_title = next_section.title) == next_section_title.upcase
          title = title.upcase
        end
        sect = Section.new node, 1
        sect.sectname = 'section'
        sect.id = node.attr 'manname-id'
        sect.title = title
        sect << (Block.new sect, :paragraph, source: %(#{node.attr 'manname'} - #{node.attr 'manpurpose'}), subs: :normal)
        sect
      end

      # Render the caption and return the height of the rendered content
      #
      # The subject argument can either be a String or an AbstractNode. If
      # subject is an AbstractNode, only call this method if the node has a
      # title (i.e., subject.title? return true).
      #--
      # TODO: allow margin to be zeroed
      def layout_caption subject, opts = {}
        if opts.delete :dry_run
          height = nil
          dry_run do
            move_down 0.001 # HACK: force top margin to be applied
            height = layout_caption subject, opts
          end
          return height
        end
        mark = { cursor: cursor, page_number: page_number }
        case subject
        when ::String
          string = subject
        when ::Asciidoctor::AbstractBlock
          string = subject.captioned_title
        else
          raise ArgumentError, 'invalid subject'
        end
        category_caption = (category = opts[:category]) ? %(#{category}_caption) : 'caption'
        container_width = bounds.width
        block_align = opts.delete :block_align
        if (align = @theme[%(#{category_caption}_align)] || @theme.caption_align)
          align = align == 'inherit' ? (block_align || @base_align) : align.to_sym
        else
          align = @base_align.to_sym
        end
        indent_by = [0, 0]
        block_width = opts.delete :block_width
        if (max_width = opts.delete :max_width) && max_width != 'none'
          if max_width == 'fit-content'
            max_width = block_width || container_width
          else
            max_width = [max_width.to_f / 100 * bounds.width, bounds.width].min if ::String === max_width && (max_width.end_with? '%')
            block_align = align
          end
          if (remainder = container_width - max_width) > 0
            case block_align
            when :right
              indent_by = [remainder, 0]
            when :center
              indent_by = [(side_margin = remainder * 0.5), side_margin]
            else # :left, nil
              indent_by = [0, remainder]
            end
          end
        end
        theme_font :caption do
          theme_font category_caption do
            caption_margin_outside = @theme[%(#{category_caption}_margin_outside)] || @theme.caption_margin_outside
            caption_margin_inside = @theme[%(#{category_caption}_margin_inside)] || @theme.caption_margin_inside
            if (side = (opts.delete :side) || :top) == :top
              margin = { top: caption_margin_outside, bottom: caption_margin_inside }
            else
              margin = { top: caption_margin_inside, bottom: caption_margin_outside }
            end
            indent(*indent_by) do
              layout_prose string, {
                margin_top: margin[:top],
                margin_bottom: margin[:bottom],
                align: align,
                normalize: false,
                normalize_line_height: true,
                hyphenate: true,
              }.merge(opts)
            end
            if side == :top && (bb_color = @theme[%(#{category_caption}_border_bottom_color)] || @theme.caption_border_bottom_color)
              stroke_horizontal_rule bb_color
              # FIXME: HACK move down slightly so line isn't covered by filled area (half width of line)
              move_down 0.25
            end
          end
        end
        # NOTE we assume we don't clear more than one page
        if page_number > mark[:page_number]
          mark[:cursor] + (bounds.top - cursor)
        else
          mark[:cursor] - cursor
        end
      end

      # Render the caption for a table and return the height of the rendered content
      def layout_table_caption node, table_alignment = :left, table_width = nil, max_width = nil, side = :top
        layout_caption node, category: :table, side: side, block_align: table_alignment, block_width: table_width, max_width: max_width
      end

      def allocate_toc doc, toc_num_levels, toc_start_y, use_title_page
        toc_page_nums = page_number
        toc_end = nil
        dry_run do
          toc_page_nums = layout_toc doc, toc_num_levels, toc_page_nums, toc_start_y
          move_down @theme.block_margin_bottom unless use_title_page
          toc_end = @y
        end
        # NOTE reserve pages for the toc; leaves cursor on page after last page in toc
        if use_title_page
          toc_page_nums.each { start_new_page }
        else
          (toc_page_nums.size - 1).times { start_new_page }
          @y = toc_end
        end
        @toc_extent = { page_nums: toc_page_nums, start_y: toc_start_y }
      end

      # NOTE num_front_matter_pages is not used during a dry run
      def layout_toc doc, num_levels = 2, toc_page_number = 2, start_y = nil, num_front_matter_pages = 0
        go_to_page toc_page_number unless (page_number == toc_page_number) || scratch?
        start_page_number = page_number
        @y = start_y if start_y
        unless (toc_title = doc.attr 'toc-title').nil_or_empty?
          theme_font :heading, level: 2 do
            theme_font :toc_title do
              toc_title_align = (@theme.toc_title_align || @theme.heading_h2_align || @theme.heading_align || @base_align).to_sym
              layout_heading toc_title, align: toc_title_align, level: 2, outdent: true
            end
          end
        end
        # QUESTION should we skip this whole method if num_levels < 0?
        unless num_levels < 0
          dot_leader = theme_font :toc do
            # TODO: we could simplify by using nested theme_font :toc_dot_leader
            if (dot_leader_font_style = (@theme.toc_dot_leader_font_style || :normal).to_sym) != font_style
              font_style dot_leader_font_style
            end
            {
              font_color: @theme.toc_dot_leader_font_color || @font_color,
              font_style: dot_leader_font_style,
              levels: ((dot_leader_l = @theme.toc_dot_leader_levels) == 'none' ? ::Set.new :
                  (dot_leader_l && dot_leader_l != 'all' ? dot_leader_l.to_s.split.map(&:to_i).to_set : (0..num_levels).to_set)),
              text: (dot_leader_text = @theme.toc_dot_leader_content || DotLeaderTextDefault),
              width: dot_leader_text.empty? ? 0 : (rendered_width_of_string dot_leader_text),
              # TODO: spacer gives a little bit of room between dots and page number
              spacer: { text: NoBreakSpace, size: (spacer_font_size = @font_size * 0.25) },
              spacer_width: (rendered_width_of_char NoBreakSpace, size: spacer_font_size),
            }
          end
          line_metrics = calc_line_metrics @theme.toc_line_height
          theme_margin :toc, :top
          layout_toc_level doc.sections, num_levels, line_metrics, dot_leader, num_front_matter_pages
        end
        # NOTE range must be calculated relative to toc_page_number; absolute page number in scratch document is arbitrary
        toc_page_numbers = (toc_page_number..(toc_page_number + (page_number - start_page_number)))
        go_to_page page_count - 1 unless scratch?
        toc_page_numbers
      end

      def layout_toc_level sections, num_levels, line_metrics, dot_leader, num_front_matter_pages = 0
        # NOTE font options aren't always reliable, so store size separately
        toc_font_info = theme_font :toc do
          { font: font, size: @font_size }
        end
        hanging_indent = @theme.toc_hanging_indent || 0
        sections.each do |sect|
          next if (num_levels_for_sect = (sect.attr 'toclevels', num_levels, false).to_i) < sect.level
          theme_font :toc, level: (sect.level + 1) do
            sect_title = ZeroWidthSpace + (@text_transform ? (transform_text sect.numbered_title, @text_transform) : sect.numbered_title)
            pgnum_label_placeholder_width = rendered_width_of_string '0' * @toc_max_pagenum_digits
            # NOTE only write section title (excluding dots and page number) if this is a dry run
            if scratch?
              indent 0, pgnum_label_placeholder_width do
                # FIXME: use layout_prose
                # NOTE must wrap title in empty anchor element in case links are styled with different font family / size
                typeset_text %(<a>#{sect_title}</a>), line_metrics, inline_format: true, hanging_indent: hanging_indent
              end
            else
              physical_pgnum = sect.attr 'pdf-page-start'
              virtual_pgnum = physical_pgnum - num_front_matter_pages
              pgnum_label = (virtual_pgnum < 1 ? (RomanNumeral.new physical_pgnum, :lower) : virtual_pgnum).to_s
              start_page_number = page_number
              start_cursor = cursor
              start_dots = nil
              sect_title_inherited = (apply_text_decoration ::Set.new, :toc, sect.level.next).merge anchor: (sect_anchor = sect.attr 'pdf-anchor'), color: @font_color
              # NOTE use text formatter to add anchor overlay to avoid using inline format with synthetic anchor tag
              sect_title_fragments = text_formatter.format sect_title, inherited: sect_title_inherited
              indent 0, pgnum_label_placeholder_width do
                sect_title_fragments[-1][:callback] = (last_fragment_pos = ::Asciidoctor::PDF::FormattedText::FragmentPositionRenderer.new)
                typeset_formatted_text sect_title_fragments, line_metrics, hanging_indent: hanging_indent
                start_dots = last_fragment_pos.right + hanging_indent
                last_fragment_cursor = last_fragment_pos.top + line_metrics.padding_top
                # NOTE this will be incorrect if wrapped line is all monospace
                if (last_fragment_page_number = last_fragment_pos.page_number) > start_page_number ||
                    (start_cursor - last_fragment_cursor) > line_metrics.height
                  start_page_number = last_fragment_page_number
                  start_cursor = last_fragment_cursor
                end
              end
              end_page_number = page_number
              end_cursor = cursor
              # TODO: it would be convenient to have a cursor mark / placement utility that took page number into account
              go_to_page start_page_number if start_page_number != end_page_number
              move_cursor_to start_cursor
              if dot_leader[:width] > 0 && (dot_leader[:levels].include? sect.level)
                pgnum_label_width = rendered_width_of_string pgnum_label
                pgnum_label_font_settings = { color: @font_color, font: font_family, size: @font_size, styles: font_styles }
                save_font do
                  # NOTE the same font is used for dot leaders throughout toc
                  set_font toc_font_info[:font], toc_font_info[:size]
                  font_style dot_leader[:font_style]
                  num_dots = ((bounds.width - start_dots - dot_leader[:spacer_width] - pgnum_label_width) / dot_leader[:width]).floor
                  # FIXME: dots don't line up in columns if width of page numbers differ
                  typeset_formatted_text [
                    { text: (dot_leader[:text] * (num_dots < 0 ? 0 : num_dots)), color: dot_leader[:font_color] },
                    dot_leader[:spacer],
                    { text: pgnum_label, anchor: sect_anchor }.merge(pgnum_label_font_settings),
                  ], line_metrics, align: :right
                end
              else
                typeset_formatted_text [{ text: pgnum_label, color: @font_color, anchor: sect_anchor }], line_metrics, align: :right
              end
              go_to_page end_page_number if page_number != end_page_number
              move_cursor_to end_cursor
            end
          end
          indent @theme.toc_indent do
            layout_toc_level sect.sections, num_levels_for_sect, line_metrics, dot_leader, num_front_matter_pages
          end if num_levels_for_sect > sect.level
        end
      end

      # Reduce icon height to fit inside bounds.height. Icons will not render
      # properly if they are larger than the current bounds.height.
      def fit_icon_to_bounds preferred_size = 24
        (max_height = bounds.height) < preferred_size ? max_height : preferred_size
      end

      def admonition_icon_data key
        if (icon_data = @theme[%(admonition_icon_#{key})])
          icon_data = (AdmonitionIcons[key] || {}).merge icon_data
          if (icon_name = icon_data[:name])
            unless icon_name.start_with?(*IconSetPrefixes)
              logger.info { %(#{key} admonition in theme uses icon from deprecated fa icon set; use fas, far, or fab instead) } unless scratch?
              icon_data[:name] = %(fa-#{icon_name}) unless icon_name.start_with? 'fa-'
            end
          end
          icon_data
        else
          AdmonitionIcons[key]
        end
      end

      # TODO: delegate to layout_page_header and layout_page_footer per page
      def layout_running_content periphery, doc, opts = {}
        skip, skip_pagenums = opts[:skip] || [1, 1]
        body_start_page_number = opts[:body_start_page_number] || 1
        # NOTE find and advance to first non-imported content page to use as model page
        return unless (content_start_page = state.pages[skip..-1].index {|it| !it.imported_page? })
        content_start_page += (skip + 1)
        num_pages = page_count
        prev_page_number = page_number
        go_to_page content_start_page

        # FIXME: probably need to treat doctypes differently
        is_book = doc.doctype == 'book'
        header = doc.header? ? doc.header : nil
        sectlevels = (@theme[%(#{periphery}_sectlevels)] || 2).to_i
        sections = doc.find_by(context: :section) {|sect| sect.level <= sectlevels && sect != header } || []
        if (toc_page_nums = @toc_extent && @toc_extent[:page_nums])
          toc_title = (doc.attr 'toc-title') || ''
        end

        title_method = TitleStyles[@theme[%(#{periphery}_title_style)]]
        # FIXME: we need a proper model for all this page counting
        # FIXME: we make a big assumption that part & chapter start on new pages
        # index parts, chapters and sections by the physical page number on which they start
        part_start_pages = {}
        chapter_start_pages = {}
        section_start_pages = {}
        trailing_section_start_pages = {}
        sections.each do |sect|
          pgnum = (sect.attr 'pdf-page-start').to_i
          if is_book && ((sect_is_part = sect.part?) || sect.chapter?)
            if sect_is_part
              part_start_pages[pgnum] ||= sect.send(*title_method)
            else
              chapter_start_pages[pgnum] ||= sect.send(*title_method)
              if sect.sectname == 'appendix' && !part_start_pages.empty?
                # FIXME: need a better way to indicate that part has ended
                part_start_pages[pgnum] = ''
              end
            end
          else
            sect_title = trailing_section_start_pages[pgnum] = sect.send(*title_method)
            section_start_pages[pgnum] ||= sect_title
          end
        end

        # index parts, chapters, and sections by the physical page number on which they appear
        parts_by_page = {}
        chapters_by_page = {}
        sections_by_page = {}
        # QUESTION should the default part be the doctitle?
        last_part = nil
        # QUESTION should we enforce that the preamble is a preface?
        last_chap = is_book ? :pre : nil
        last_sect = nil
        sect_search_threshold = 1
        (1..num_pages).each do |pgnum|
          if (part = part_start_pages[pgnum])
            last_part = part
            last_chap = nil
            last_sect = nil
          end
          if (chap = chapter_start_pages[pgnum])
            last_chap = chap
            last_sect = nil
          end
          if (sect = section_start_pages[pgnum])
            last_sect = sect
          elsif part || chap
            sect_search_threshold = pgnum
          # NOTE we didn't find a section on this page; look back to find last section started
          elsif last_sect
            (sect_search_threshold..(pgnum - 1)).reverse_each do |prev|
              if (sect = trailing_section_start_pages[prev])
                last_sect = sect
                break
              end
            end
          end
          parts_by_page[pgnum] = last_part
          if last_chap == :pre
            if pgnum >= body_start_page_number
              chapters_by_page[pgnum] = is_book ? (doc.attr 'preface-title', 'Preface') : nil
            elsif toc_page_nums && (toc_page_nums.cover? pgnum)
              chapters_by_page[pgnum] = toc_title
            else
              chapters_by_page[pgnum] = doc.doctitle
            end
          else
            chapters_by_page[pgnum] = last_chap
          end
          sections_by_page[pgnum] = last_sect
        end

        doctitle = doc.doctitle partition: true, use_fallback: true
        # NOTE set doctitle again so it's properly escaped
        doc.set_attr 'doctitle', doctitle.combined
        doc.set_attr 'document-title', doctitle.main
        doc.set_attr 'document-subtitle', doctitle.subtitle
        doc.set_attr 'page-count', (num_pages - skip_pagenums)

        pagenums_enabled = doc.attr? 'pagenums'
        case @media == 'prepress' ? 'physical' : (doc.attr 'pdf-folio-placement')
        when 'physical'
          folio_basis, invert_folio = :physical, false
        when 'physical-inverted'
          folio_basis, invert_folio = :physical, true
        when 'virtual-inverted'
          folio_basis, invert_folio = :virtual, true
        else
          folio_basis, invert_folio = :virtual, false
        end
        periphery_layout_cache = {}
        # NOTE: this block is invoked during PDF generation, after convert_document has returned
        repeat (content_start_page..num_pages), dynamic: true do
          # NOTE: don't write on pages which are imported / inserts (otherwise we can get a corrupt PDF)
          if page.imported_page?
            remove_tmp_files if page_number == num_pages
            next
          end
          virtual_pgnum = (pgnum = page_number) - skip_pagenums
          pgnum_label = (virtual_pgnum < 1 ? (RomanNumeral.new pgnum, :lower) : virtual_pgnum).to_s
          side = page_side((folio_basis == :physical ? pgnum : virtual_pgnum), invert_folio)
          # QUESTION should allocation be per side?
          trim_styles, colspec_dict, content_dict, stamp_names = allocate_running_content_layout doc, page, periphery, periphery_layout_cache
          # FIXME: we need to have a content setting for chapter pages
          content_by_position, colspec_by_position = content_dict[side], colspec_dict[side]
          # TODO: populate chapter-number
          # TODO: populate numbered and unnumbered chapter and section titles
          doc.set_attr 'page-number', pgnum_label if pagenums_enabled
          # QUESTION should the fallback value be nil instead of empty string? or should we remove attribute if no value?
          doc.set_attr 'part-title', (parts_by_page[pgnum] || '')
          if toc_page_nums && (toc_page_nums.cover? pgnum)
            if is_book
              doc.set_attr 'chapter-title', (sect_or_chap_title = toc_title)
              doc.set_attr 'section-title', ''
            else
              doc.set_attr 'chapter-title', ''
              doc.set_attr 'section-title', (sect_or_chap_title = section_start_pages[pgnum] ? sections_by_page[pgnum] : toc_title)
            end
            doc.set_attr 'section-or-chapter-title', sect_or_chap_title
            toc_page_nums = nil if toc_page_nums.end == pgnum
          else
            doc.set_attr 'chapter-title', (chapters_by_page[pgnum] || '')
            doc.set_attr 'section-title', (sections_by_page[pgnum] || '')
            doc.set_attr 'section-or-chapter-title', (sections_by_page[pgnum] || chapters_by_page[pgnum] || '')
          end

          stamp stamp_names[side] if stamp_names

          theme_font periphery do
            canvas do
              bounding_box [trim_styles[:content_left][side], trim_styles[:top]], width: trim_styles[:content_width][side], height: trim_styles[:height] do
                if (trim_column_rule_width = trim_styles[:column_rule_width]) > 0
                  trim_column_rule_spacing = trim_styles[:column_rule_spacing]
                else
                  trim_column_rule_width = nil
                end
                prev_position = nil
                ColumnPositions.each do |position|
                  next unless (content = content_by_position[position])
                  next unless (colspec = colspec_by_position[position])[:width] > 0
                  left, colwidth = colspec[:x], colspec[:width]
                  if trim_column_rule_width && colwidth < bounds.width
                    if (trim_column_rule = prev_position)
                      left += (trim_column_rule_spacing * 0.5)
                      colwidth -= trim_column_rule_spacing
                    else
                      colwidth -= (trim_column_rule_spacing * 0.5)
                    end
                  end
                  # FIXME: we need to have a content setting for chapter pages
                  case content
                  when ::Array
                    # NOTE float ensures cursor position is restored and returns us to current page if we overrun
                    float do
                      # NOTE bounding_box is redundant if both vertical padding and border width are 0
                      bounding_box [left, bounds.top - trim_styles[:padding][0] - trim_styles[:content_offset]], width: colwidth, height: trim_styles[:content_height] do
                        # NOTE image vposition respects padding; use negative image_vertical_align value to revert
                        image_opts = content[1].merge position: colspec[:align], vposition: trim_styles[:img_valign]
                        begin
                          image_info = image content[0], image_opts
                          if (image_link = content[2])
                            image_info = { width: image_info.scaled_width, height: image_info.scaled_height } unless image_opts[:format] == 'svg'
                            add_link_to_image image_link, image_info, image_opts
                          end
                        rescue
                          logger.warn %(could not embed image in running content: #{content[0]}; #{$!.message})
                        end
                      end
                    end
                  when ::String
                    theme_font %(#{periphery}_#{side}_#{position}) do
                      # NOTE minor optimization
                      if content == '{page-number}'
                        content = pagenums_enabled ? pgnum_label : nil
                      else
                        content = apply_subs_discretely doc, content, drop_lines_with_unresolved_attributes: true
                        content = transform_text content, @text_transform if @text_transform
                      end
                      formatted_text_box parse_text(content, color: @font_color, inline_format: [normalize: true]),
                          at: [left, bounds.top - trim_styles[:padding][0] - trim_styles[:content_offset] + ((Array trim_styles[:valign])[0] == :center ? font.descender * 0.5 : 0)],
                          width: colwidth,
                          height: trim_styles[:prose_content_height],
                          align: colspec[:align],
                          valign: trim_styles[:valign],
                          leading: trim_styles[:line_metrics].leading,
                          final_gap: false,
                          overflow: :truncate
                    end
                  end
                  bounding_box [colspec[:x], bounds.top - trim_styles[:padding][0] - trim_styles[:content_offset]], width: colspec[:width], height: trim_styles[:content_height] do
                    stroke_vertical_rule trim_styles[:column_rule_color], at: bounds.left, line_style: trim_styles[:column_rule_style], line_width: trim_column_rule_width
                  end if trim_column_rule
                  prev_position = position
                end
              end
            end
          end
          remove_tmp_files if pgnum == num_pages
        end

        go_to_page prev_page_number
        nil
      end

      def allocate_running_content_layout doc, page, periphery, cache
        cache[layout = page.layout] ||= begin
          valign, valign_offset = @theme[%(#{periphery}_vertical_align)]
          if (valign = (valign || :middle).to_sym) == :middle
            valign = :center
          end
          trim_styles = {
            line_metrics: (trim_line_metrics = calc_line_metrics @theme[%(#{periphery}_line_height)] || @theme.base_line_height),
            # NOTE we've already verified this property is set
            height: (trim_height = @theme[%(#{periphery}_height)]),
            top: periphery == :header ? page_height : trim_height,
            padding: (trim_padding = inflate_padding @theme[%(#{periphery}_padding)] || 0),
            bg_color: (resolve_theme_color %(#{periphery}_background_color).to_sym),
            border_color: (trim_border_color = resolve_theme_color %(#{periphery}_border_color).to_sym),
            border_style: (@theme[%(#{periphery}_border_style)] || :solid).to_sym,
            border_width: (trim_border_width = trim_border_color ? @theme[%(#{periphery}_border_width)] || @theme.base_border_width || 0 : 0),
            column_rule_color: (trim_column_rule_color = resolve_theme_color %(#{periphery}_column_rule_color).to_sym),
            column_rule_style: (@theme[%(#{periphery}_column_rule_style)] || :solid).to_sym,
            column_rule_width: (trim_column_rule_color ? @theme[%(#{periphery}_column_rule_width)] || 0 : 0),
            column_rule_spacing: (@theme[%(#{periphery}_column_rule_spacing)] || 0),
            valign: valign_offset ? [valign, valign_offset] : valign,
            img_valign: @theme[%(#{periphery}_image_vertical_align)],
            left: {
              recto: (trim_left_recto = @page_margin_by_side[:recto][3]),
              verso: (trim_left_verso = @page_margin_by_side[:verso][3]),
            },
            width: {
              recto: (trim_width_recto = page_width - trim_left_recto - @page_margin_by_side[:recto][1]),
              verso: (trim_width_verso = page_width - trim_left_verso - @page_margin_by_side[:verso][1]),
            },
            content_left: {
              recto: trim_left_recto + trim_padding[3],
              verso: trim_left_verso + trim_padding[3],
            },
            content_width: (trim_content_width = {
              recto: trim_width_recto - trim_padding[1] - trim_padding[3],
              verso: trim_width_verso - trim_padding[1] - trim_padding[3],
            }),
            content_height: (content_height = trim_height - trim_padding[0] - trim_padding[2] - (trim_border_width * 0.5)),
            prose_content_height: content_height - trim_line_metrics.padding_top - trim_line_metrics.padding_bottom,
            # NOTE content offset adjusts y position to account for border
            content_offset: (periphery == :footer ? trim_border_width * 0.5 : 0),
          }
          case trim_styles[:img_valign]
          when nil
            trim_styles[:img_valign] = valign
          when 'middle'
            trim_styles[:img_valign] = :center
          when 'top', 'center', 'bottom'
            trim_styles[:img_valign] = trim_styles[:img_valign].to_sym
          end

          if (trim_bg_image = resolve_background_image doc, @theme, %(#{periphery}_background_image).to_sym, container_size: [page_width, trim_height]) && trim_bg_image[0]
            trim_styles[:bg_image] = trim_bg_image
          else
            trim_bg_image = nil
          end

          colspec_dict = PageSides.each_with_object({}) do |side, acc|
            side_trim_content_width = trim_content_width[side]
            if (custom_colspecs = @theme[%(#{periphery}_#{side}_columns)] || @theme[%(#{periphery}_columns)])
              case (colspecs = (custom_colspecs.to_s.tr ',', ' ').split).size
              when 0, 1
                colspecs = { left: '0', center: colspecs[0] || '100', right: '0' }
              when 2
                colspecs = { left: colspecs[0], center: '0', right: colspecs[1] }
              else # 3
                colspecs = { left: colspecs[0], center: colspecs[1], right: colspecs[2] }
              end
              tot_width = 0
              side_colspecs = colspecs.map {|col, spec|
                if (alignment_char = spec.chr).to_i.to_s != alignment_char
                  alignment = AlignmentTable[alignment_char] || :left
                  rel_width = (spec.slice 1, spec.length).to_f
                else
                  alignment = :left
                  rel_width = spec.to_f
                end
                tot_width += rel_width
                [col, { align: alignment, width: rel_width, x: 0 }]
              }.to_h
              # QUESTION should we allow the columns to overlap (capping width at 100%)?
              side_colspecs.each {|_, colspec| colspec[:width] = (colspec[:width] / tot_width) * side_trim_content_width }
              side_colspecs[:right][:x] = (side_colspecs[:center][:x] = side_colspecs[:left][:width]) + side_colspecs[:center][:width]
              acc[side] = side_colspecs
            else
              acc[side] = {
                left: { align: :left, width: side_trim_content_width, x: 0 },
                center: { align: :center, width: side_trim_content_width, x: 0 },
                right: { align: :right, width: side_trim_content_width, x: 0 },
              }
            end
          end

          content_dict = PageSides.each_with_object({}) do |side, acc|
            side_content = {}
            ColumnPositions.each do |position|
              unless (val = @theme[%(#{periphery}_#{side}_#{position}_content)]).nil_or_empty?
                if (val.include? ':') && val =~ ImageAttributeValueRx
                  attrlist = $2
                  image_attrs = (AttributeList.new attrlist).parse %w(alt width)
                  image_path, image_format = ::Asciidoctor::Image.target_and_format $1, image_attrs
                  if (image_path = resolve_image_path doc, image_path, @themesdir, image_format) && (::File.readable? image_path)
                    image_opts = resolve_image_options image_path, image_attrs, container_size: [colspec_dict[side][position][:width], trim_styles[:content_height]], format: image_format
                    side_content[position] = [image_path, image_opts, image_attrs['link']]
                  else
                    # NOTE allows inline image handler to report invalid reference and replace with alt text
                    side_content[position] = %(image:#{image_path}[#{attrlist}])
                  end
                else
                  side_content[position] = val
                end
              end
            end

            acc[side] = side_content
          end

          if (trim_bg_color = trim_styles[:bg_color]) || trim_bg_image || trim_border_width > 0
            stamp_names = { recto: %(#{layout}_#{periphery}_recto), verso: %(#{layout}_#{periphery}_verso) }
            PageSides.each do |side|
              create_stamp stamp_names[side] do
                canvas do
                  if trim_bg_color || trim_bg_image
                    bounding_box [0, trim_styles[:top]], width: bounds.width, height: trim_styles[:height] do
                      fill_bounds trim_bg_color if trim_bg_color
                      if trim_border_width > 0
                        stroke_horizontal_rule trim_styles[:border_color], line_width: trim_border_width, line_style: trim_styles[:border_style], at: (periphery == :header ? bounds.height : 0)
                      end
                      # NOTE: must draw line first or SVG will cause border to disappear
                      image trim_bg_image[0], ({ position: :center, vposition: :center }.merge trim_bg_image[1]) if trim_bg_image
                    end
                  elsif trim_border_width > 0
                    bounding_box [trim_styles[:left][side], trim_styles[:top]], width: trim_styles[:width][side], height: trim_styles[:height] do
                      stroke_horizontal_rule trim_styles[:border_color], line_width: trim_styles[:border_width], line_style: trim_styles[:border_style], at: (periphery == :header ? bounds.height : 0)
                    end
                  end
                end
              end
            end
          end

          [trim_styles, colspec_dict, content_dict, stamp_names]
        end
      end

      def add_outline doc, num_levels = 2, toc_page_nums = [], num_front_matter_pages = 0, has_front_cover = false
        if ::String === num_levels
          if num_levels.include? ':'
            num_levels, expand_levels = num_levels.split ':', 2
            num_levels = num_levels.empty? ? (doc.attr 'toclevels', 2).to_i : num_levels.to_i
            expand_levels = expand_levels.to_i
          else
            num_levels = expand_levels = num_levels.to_i
          end
        else
          expand_levels = num_levels
        end
        front_matter_counter = RomanNumeral.new 0, :lower
        pagenum_labels = {}

        num_front_matter_pages.times do |n|
          pagenum_labels[n] = { P: (::PDF::Core::LiteralString.new front_matter_counter.next!.to_s) }
        end

        # add labels for each content page, which is required for reader's page navigator to work correctly
        (num_front_matter_pages..(page_count - 1)).each_with_index do |n, i|
          pagenum_labels[n] = { P: (::PDF::Core::LiteralString.new (i + 1).to_s) }
        end

        unless toc_page_nums.none? || (toc_title = doc.attr 'toc-title').nil_or_empty?
          toc_section = insert_toc_section doc, toc_title, toc_page_nums
        end

        outline.define do
          initial_pagenum = has_front_cover ? 2 : 1
          # FIXME: use sanitize: :plain_text once available
          if document.page_count >= initial_pagenum && (doctitle = doc.header? ? doc.doctitle : (doc.attr 'untitled-label'))
            page title: (document.sanitize doctitle), destination: (document.dest_top has_front_cover ? 2 : 1)
          end
          # QUESTION is there any way to get add_outline_level to invoke in the context of the outline?
          document.add_outline_level self, doc.sections, num_levels, expand_levels
        end

        toc_section.parent.blocks.delete toc_section if toc_section

        catalog.data[:PageLabels] = state.store.ref Nums: pagenum_labels.flatten
        primary_page_mode, secondary_page_mode = PageModes[(doc.attr 'pdf-page-mode') || @theme.page_mode]
        catalog.data[:PageMode] = primary_page_mode
        catalog.data[:NonFullScreenPageMode] = secondary_page_mode if secondary_page_mode
        nil
      end

      def add_outline_level outline, sections, num_levels, expand_levels
        sections.each do |sect|
          sect_title = sanitize sect.numbered_title formal: true
          sect_destination = sect.attr 'pdf-destination'
          if (level = sect.level) == num_levels || !sect.sections?
            outline.page title: sect_title, destination: sect_destination
          elsif level <= num_levels
            outline.section sect_title, destination: sect_destination, closed: expand_levels < 1 do
              add_outline_level outline, sect.sections, num_levels, (expand_levels - 1)
            end
          end
        end
      end

      def insert_toc_section doc, toc_title, toc_page_nums
        if (doc.attr? 'toc-placement', 'macro') && (toc_node = (doc.find_by context: :toc)[0])
          if (parent_section = toc_node.parent).context == :section
            grandparent_section = parent_section.parent
            toc_level = parent_section.level
            insert_idx = (grandparent_section.blocks.index parent_section) + 1
          else
            grandparent_section = doc
            toc_level = doc.sections[0].level
            insert_idx = 0
          end
          toc_dest = toc_node.attr 'pdf-destination'
        else
          grandparent_section = doc
          toc_level = doc.sections[0].level
          insert_idx = 0
          toc_dest = dest_top toc_page_nums.first
        end
        toc_section = Section.new grandparent_section, toc_level, false, attributes: { 'pdf-destination' => toc_dest }
        toc_section.title = toc_title
        grandparent_section.blocks.insert insert_idx, toc_section
        toc_section
      end

      def write pdf_doc, target
        if target.respond_to? :write
          target = ::QuantifiableStdout.new $stdout if target == $stdout
          pdf_doc.render target
        else
          pdf_doc.render_file target
          # QUESTION restore attributes first?
          @pdfmark&.generate_file target
          (Optimizer.new @optimize, pdf_doc.min_version).generate_file target if @optimize && ((defined? ::Asciidoctor::PDF::Optimizer) || !(Helpers.require_library OptimizerRequirePath, 'rghost', :warn).nil?)
        end
        # write scratch document if debug is enabled (or perhaps DEBUG_STEPS env)
        #get_scratch_document.render_file 'scratch.pdf'
        nil
      end

      def register_fonts font_catalog, fonts_dir
        return unless font_catalog
        dirs = (fonts_dir.split ValueSeparatorRx, -1).map do |dir|
          dir == 'GEM_FONTS_DIR' || dir.empty? ? ThemeLoader::FontsDir : dir
        end
        font_catalog.each do |key, styles|
          styles = styles.each_with_object({}) do |(style, path), accum|
            found = dirs.find do |dir|
              resolved_font_path = font_path path, dir
              if ::File.readable? resolved_font_path
                accum[style.to_sym] = resolved_font_path
                true
              end
            end
            raise ::Errno::ENOENT, ((File.absolute_path? path) ? %(#{path} not found) : %(#{path} not found in #{fonts_dir.gsub ValueSeparatorRx, ' or '})) unless found
          end
          register_font key => styles
        end
      end

      def font_path font_file, fonts_dir
        # resolve relative to built-in font dir unless path is absolute
        ::File.absolute_path font_file, fonts_dir
      end

      def fallback_svg_font_name
        @theme.svg_fallback_font_family || @theme.svg_font_family || @theme.base_font_family
      end

      def apply_text_decoration styles, category, level = nil
        if (text_decoration_style = TextDecorationStyleTable[(level && @theme[%(#{category}_h#{level}_text_decoration)]) || @theme[%(#{category}_text_decoration)]])
          {
            styles: (styles << text_decoration_style),
            text_decoration_color: (level && @theme[%(#{category}_h#{level}_text_decoration_color)]) || @theme[%(#{category}_text_decoration_color)],
            text_decoration_width: (level && @theme[%(#{category}_h#{level}_text_decoration_width)]) || @theme[%(#{category}_text_decoration_width)],
          }.compact
        else
          styles.empty? ? {} : { styles: styles }
        end
      end

      def resolve_text_transform key, use_fallback = true
        if (transform = ::Hash === key ? (key.delete :text_transform) : @theme[key.to_s])
          transform == 'none' ? nil : transform
        elsif use_fallback
          @text_transform
        end
      end

      # QUESTION should we pass a category as an argument?
      # QUESTION should we make this a method on the theme ostruct? (e.g., @theme.resolve_color key, fallback)
      def resolve_theme_color key, fallback_color = nil
        if (color = @theme[key.to_s]) && color != 'transparent'
          color
        else
          fallback_color
        end
      end

      def resolve_font_kerning keyword, fallback = default_kerning?
        keyword && (FontKerningTable.key? keyword) ? FontKerningTable[keyword] : fallback
      end

      def theme_fill_and_stroke_bounds category, opts = {}
        bg_color = (opts.key? :background_color) ? opts[:background_color] : @theme[%(#{category}_background_color)]
        fill_and_stroke_bounds bg_color, @theme[%(#{category}_border_color)],
            line_width: (@theme[%(#{category}_border_width)] || 0),
            radius: @theme[%(#{category}_border_radius)]
      end

      def theme_fill_and_stroke_block category, block_height, opts = {}
        if (b_width = (opts.key? :border_width) ? opts[:border_width] : @theme[%(#{category}_border_width)])
          b_width = nil unless b_width > 0
        end
        if (bg_color = opts[:background_color] || @theme[%(#{category}_background_color)]) == 'transparent'
          bg_color = nil
        end
        unless b_width || bg_color
          (node = opts[:caption_node]) && node.title? && (layout_caption node, category: category)
          return
        end
        if (b_color = @theme[%(#{category}_border_color)]) == 'transparent'
          b_color = @page_bg_color
        end
        b_radius = (@theme[%(#{category}_border_radius)] || 0) + (b_width || 0)
        if b_width && b_color
          if b_color == @page_bg_color # let page background cut into block background
            b_gap_color, b_shift = @page_bg_color, b_width
          elsif (b_gap_color = bg_color) && b_gap_color != b_color
            b_shift = 0
          else # let page background cut into border
            b_gap_color, b_shift = @page_bg_color, 0
          end
        else # let page background cut into block background
          b_shift, b_gap_color = (b_width ||= 0.5) * 0.5, @page_bg_color
        end
        # FIXME: due to the calculation error logged in #789, we must advance page even when content is split across pages
        advance_page if (opts.fetch :split_from_top, true) && block_height > cursor && !at_page_top?
        caption_height = (node = opts[:caption_node]) && node.title? ? (layout_caption node, category: category) : 0
        float do
          remaining_height = block_height - caption_height
          initial_page = true
          while remaining_height > 0
            advance_page unless initial_page
            chunk_height = [(available_height = cursor), remaining_height].min
            bounding_box [0, available_height], width: bounds.width, height: chunk_height do
              theme_fill_and_stroke_bounds category, background_color: bg_color
              if b_width
                indent b_radius, b_radius do
                  # dashed line indicates continuation from previous page; swell line slightly to cover background
                  stroke_horizontal_rule b_gap_color, line_width: b_width * 1.2, line_style: :dashed, at: b_shift
                end unless initial_page
                if remaining_height > chunk_height
                  move_down chunk_height - b_shift
                  indent b_radius, b_radius do
                    # dashed line indicates continuation from previous page; swell line slightly to cover background
                    stroke_horizontal_rule b_gap_color, line_width: b_width * 1.2, line_style: :dashed
                  end
                end
              end
            end
            initial_page = false
            remaining_height -= chunk_height
          end
        end
      end

      # Insert a top margin equal to amount if cursor is not at the top of the
      # page. Start a new page instead if amount is greater than the remaining
      # space on the page.
      def margin_top amount
        margin amount, :top
      end

      # Insert a bottom margin equal to amount unless cursor is at the top of the
      # page (not likely). Start a new page instead if amount is greater than the
      # remaining space on the page.
      def margin_bottom amount
        margin amount, :bottom
      end

      # Insert a margin at the specified side if the cursor is not at the top of
      # the page. Start a new page if amount is greater than the remaining space on
      # the page.
      def margin amount, _side
        unless (amount || 0) == 0 || at_page_top?
          # NOTE use low-level cursor calculation to workaround cursor bug in column_box context
          if y - reference_bounds.absolute_bottom > amount
            move_down amount
          else
            # set cursor at top of next page
            reference_bounds.move_past_bottom
          end
        end
      end

      # Lookup margin for theme element and side, then delegate to margin method.
      # If margin value is not found, assume:
      # - 0 when side == :top
      # - @theme.vertical_spacing when side == :bottom
      def theme_margin category, side
        margin((@theme[%(#{category}_margin_#{side})] || (side == :bottom ? @theme.vertical_spacing : 0)), side)
      end

      def theme_font category, opts = {}
        result = nil
        # TODO: inheriting from generic category should be an option
        if opts.key? :level
          hlevel_category = %(#{category}_h#{opts[:level]})
          family = @theme[%(#{hlevel_category}_font_family)] || @theme[%(#{category}_font_family)] || @theme.base_font_family || font_family
          size = @theme[%(#{hlevel_category}_font_size)] || @theme[%(#{category}_font_size)] || @root_font_size
          style = @theme[%(#{hlevel_category}_font_style)] || @theme[%(#{category}_font_style)]
          color = @theme[%(#{hlevel_category}_font_color)] || @theme[%(#{category}_font_color)]
          kerning = resolve_font_kerning @theme[%(#{hlevel_category}_font_kerning)] || @theme[%(#{category}_font_kerning)], nil
          # NOTE global text_transform is not currently supported
          transform = @theme[%(#{hlevel_category}_text_transform)] || @theme[%(#{category}_text_transform)]
        else
          inherited_font = font_info
          family = @theme[%(#{category}_font_family)] || inherited_font[:family]
          size = @theme[%(#{category}_font_size)] || inherited_font[:size]
          style = @theme[%(#{category}_font_style)] || inherited_font[:style]
          color = @theme[%(#{category}_font_color)]
          kerning = resolve_font_kerning @theme[%(#{category}_font_kerning)], nil
          # NOTE global text_transform is not currently supported
          transform = @theme[%(#{category}_text_transform)]
        end

        prev_color, @font_color = @font_color, color if color
        prev_kerning, self.default_kerning = default_kerning?, kerning unless kerning.nil?
        prev_transform, @text_transform = @text_transform, (transform == 'none' ? nil : transform) if transform

        font family, size: size, style: (style && style.to_sym) do
          result = yield
        end

        @font_color = prev_color if color
        default_kerning prev_kerning unless kerning.nil?
        @text_transform = prev_transform if transform
        result
      end

      # Calculate the font size (down to the minimum font size) that would allow
      # all the specified fragments to fit in the available width without wrapping lines.
      #
      # Return the calculated font size if an adjustment is necessary or nil if no
      # font size adjustment is necessary.
      def theme_font_size_autofit fragments, category
        arranger = arrange_fragments_by_line fragments
        theme_font category do
          # NOTE finalizing the line here generates fragments & calculates their widths using the current font settings
          # CAUTION it also removes zero-width spaces
          arranger.finalize_line
          actual_width = width_of_fragments arranger.fragments
          unless ::Array === (padding = @theme[%(#{category}_padding)])
            padding = ::Array.new 4, padding
          end
          available_width = bounds.width - (padding[3] || 0) - (padding[1] || 0)
          if actual_width > available_width
            adjusted_font_size = ((available_width * font_size).to_f / actual_width).truncate 4
            if (min = @theme[%(#{category}_font_size_min)] || @theme.base_font_size_min) && adjusted_font_size < min
              min
            else
              adjusted_font_size
            end
          end
        end
      end

      # Arrange fragments by line in an arranger and return an unfinalized arranger.
      #
      # Finalizing the arranger is deferred since it must be done in the context of
      # the global font settings you want applied to each fragment.
      def arrange_fragments_by_line fragments, _opts = {}
        arranger = ::Prawn::Text::Formatted::Arranger.new self
        by_line = arranger.consumed = []
        fragments.each do |fragment|
          if (text = fragment[:text]) == LF
            by_line << fragment
          elsif text.include? LF
            text.scan LineScanRx do |line|
              by_line << (line == LF ? { text: LF } : (fragment.merge text: line))
            end
          else
            by_line << fragment
          end
        end
        arranger
      end

      # Calculate the width that is needed to print all the
      # fragments without wrapping any lines.
      #
      # This method assumes endlines are represented as discrete entries in the
      # fragments array.
      def width_of_fragments fragments
        line_widths = [0]
        fragments.each do |fragment|
          if fragment.text == LF
            line_widths << 0
          else
            line_widths[-1] += fragment.width
          end
        end
        line_widths.max
      end

      # Compute the rendered width of a string, taking fallback fonts into account
      def rendered_width_of_string str, opts = {}
        opts = opts.merge kerning: default_kerning?
        if str.length == 1
          rendered_width_of_char str, opts
        elsif (chars = str.each_char).all? {|char| font.glyph_present? char }
          width_of_string str, opts
        else
          char_widths = chars.map {|char| rendered_width_of_char char, opts }
          char_widths.sum + (char_widths.length * character_spacing)
        end
      end

      # Compute the rendered width of a char, taking fallback fonts into account
      def rendered_width_of_char char, opts = {}
        unless @fallback_fonts.empty? || (font.glyph_present? char)
          @fallback_fonts.each do |fallback_font|
            font fallback_font do
              return width_of_string char, opts if font.glyph_present? char
            end
          end
        end
        width_of_string char, opts
      end

      # TODO: document me, esp the first line formatting functionality
      def typeset_text string, line_metrics, opts = {}
        move_down line_metrics.padding_top
        opts = { leading: line_metrics.leading, final_gap: line_metrics.final_gap }.merge opts
        string = string.gsub CjkLineBreakRx, ZeroWidthSpace if @cjk_line_breaks
        if (hanging_indent = (opts.delete :hanging_indent) || 0) > 0
          indent hanging_indent do
            text string, (opts.merge indent_paragraphs: -hanging_indent)
          end
        elsif (first_line_opts = opts.delete :first_line_options)
          # TODO: good candidate for Prawn enhancement!
          text_with_formatted_first_line string, first_line_opts, opts
        else
          text string, opts
        end
        move_down line_metrics.padding_bottom
      end

      # QUESTION combine with typeset_text?
      def typeset_formatted_text fragments, line_metrics, opts = {}
        move_down line_metrics.padding_top
        opts = { leading: line_metrics.leading, final_gap: line_metrics.final_gap }.merge opts
        if (hanging_indent = (opts.delete :hanging_indent) || 0) > 0
          indent hanging_indent do
            formatted_text fragments, (opts.merge indent_paragraphs: -hanging_indent)
          end
        else
          formatted_text fragments, opts
        end
        move_down line_metrics.padding_bottom
      end

      def height_of_typeset_text string, opts = {}
        line_metrics = (calc_line_metrics opts[:line_height] || @theme.base_line_height)
        (height_of string, leading: line_metrics.leading, final_gap: line_metrics.final_gap) + line_metrics.padding_top + (opts[:single_line] ? 0 : line_metrics.padding_bottom)
      end

      # NOTE only used when tabsize attribute is not specified
      # tabs must always be replaced with spaces in order for the indentation guards to work
      def expand_tabs string
        if string.nil_or_empty?
          ''
        elsif string.include? TAB
          full_tab_space = ' ' * (tab_size = 4)
          (string.split LF, -1).map {|line|
            if line.empty?
              line
            elsif (tab_idx = line.index TAB)
              if tab_idx == 0
                leading_tabs = 0
                line.each_byte do |b|
                  break unless b == 9
                  leading_tabs += 1
                end
                line = %(#{full_tab_space * leading_tabs}#{rest = line.slice leading_tabs, line.length})
                next line unless rest.include? TAB
              end
              # keeps track of how many spaces were added to adjust offset in match data
              spaces_added = 0
              idx = 0
              result = ''
              line.each_char do |c|
                if c == TAB
                  # calculate how many spaces this tab represents, then replace tab with spaces
                  if (offset = idx + spaces_added) % tab_size == 0
                    spaces_added += (tab_size - 1)
                    result += full_tab_space
                  else
                    unless (spaces = tab_size - offset % tab_size) == 1
                      spaces_added += (spaces - 1)
                    end
                    result += (' ' * spaces)
                  end
                else
                  result += c
                end
                idx += 1
              end
              result
            else
              line
            end
          }.join LF
        else
          string
        end
      end

      # Add an indentation guard at the start of indented lines.
      # Expand tabs to spaces if tabs are present
      def guard_indentation string
        unless (string = expand_tabs string).empty?
          string[0] = GuardedIndent if string.start_with? ' '
          string.gsub! InnerIndent, GuardedInnerIndent if string.include? InnerIndent
        end
        string
      end

      def guard_indentation_in_fragments fragments
        start_of_line = true
        fragments.each do |fragment|
          next if (text = fragment[:text]).empty?
          if start_of_line && (text.start_with? ' ')
            fragment[:text] = GuardedIndent + (((text = text.slice 1, text.length).include? InnerIndent) ? (text.gsub InnerIndent, GuardedInnerIndent) : text)
          elsif text.include? InnerIndent
            fragment[:text] = text.gsub InnerIndent, GuardedInnerIndent
          end
          start_of_line = text.end_with? LF
        end
        fragments
      end

      # Derive a PDF-safe, ASCII-only anchor name from the given value.
      # Encodes value into hex if it contains characters outside the ASCII range.
      # If value is nil, derive an anchor name from the default_value, if given.
      def derive_anchor_from_id value, default_value = nil
        if value
          value.ascii_only? ? value : %(0x#{::PDF::Core.string_to_hex value})
        elsif default_value
          %(__anchor-#{default_value})
        end
      end

      # If an id is provided or the node passed as the first argument has an id,
      # add a named destination to the document equivalent to the node id at the
      # current y position. If the node does not have an id and an id is not
      # specified, do nothing.
      #
      # If the node is a section, and the current y position is the top of the
      # page, set the y position equal to the page height to improve the navigation
      # experience. If the current x position is at or inside the left margin, set
      # the x position equal to 0 (left edge of page) to improve the navigation
      # experience.
      def add_dest_for_block node, id = nil
        if !scratch? && (id ||= node.id)
          dest_x = bounds.absolute_left.truncate 4
          # QUESTION when content is aligned to left margin, should we keep precise x value or just use 0?
          dest_x = 0 if dest_x <= page_margin_left
          dest_y = at_page_top? && (node.context == :section || node.context == :document) ? page_height : y
          # TODO: find a way to store only the ref of the destination; look it up when we need it
          node.set_attr 'pdf-destination', (node_dest = (dest_xyz dest_x, dest_y))
          add_dest id, node_dest
        end
        nil
      end

      def resolve_alignment_from_role roles
        if (align_role = roles.reverse.find {|r| TextAlignmentRoles.include? r })
          (align_role.slice 5, align_role.length).to_sym
        end
      end

      # QUESTION is this method still necessary?
      def resolve_imagesdir doc
        if (imagesdir = doc.attr 'imagesdir').nil_or_empty? || (imagesdir = imagesdir.chomp '/') == '.'
          nil
        else
          imagesdir
        end
      end

      # Resolve the system path of the specified image path.
      #
      # Resolve and normalize the absolute system path of the specified image,
      # taking into account the imagesdir attribute. If an image path is not
      # specified, the path is read from the target attribute of the specified
      # document node.
      #
      # If the target is a URI and the allow-uri-read attribute is set on the
      # document, read the file contents to a temporary file and return the path to
      # the temporary file. If the target is a URI and the allow-uri-read attribute
      # is not set, or the URI cannot be read, this method returns a nil value.
      #
      # When a temporary file is used, the file is stored in @tmp_files to be cleaned up after conversion.
      def resolve_image_path node, image_path = nil, relative_to = true, image_format = nil
        doc = node.document
        imagesdir = relative_to == true ? (resolve_imagesdir doc) : relative_to
        image_path ||= node.attr 'target'
        image_format ||= ::Asciidoctor::Image.format image_path, (::Asciidoctor::Image === node ? node.attributes : nil)
        # NOTE base64 logic currently used for inline images
        if ::Base64 === image_path
          return @tmp_files[image_path] if @tmp_files.key? image_path
          tmp_image = ::Tempfile.create ['image-', image_format && %(.#{image_format})]
          tmp_image.binmode unless image_format == 'svg'
          begin
            tmp_image.write ::Base64.decode64 image_path
            tmp_image.close
            @tmp_files[image_path] = tmp_image.path
          rescue
            @tmp_files[image_path] = nil
            tmp_image.close
            unlink_tmp_file tmp_image.path
            nil
          end
        # NOTE: this will catch a classloader resource path on JRuby (e.g., uri:classloader:/path/to/image)
        elsif ::File.absolute_path? image_path
          ::File.absolute_path image_path
        elsif !(is_uri = node.is_uri? image_path) && imagesdir && (::File.absolute_path? imagesdir)
          ::File.absolute_path image_path, imagesdir
        elsif is_uri || (imagesdir && (node.is_uri? imagesdir) && (image_path = node.normalize_web_path image_path, imagesdir, false))
          if !allow_uri_read
            logger.warn %(allow-uri-read is not enabled; cannot embed remote image: #{image_path}) unless scratch?
            return
          elsif @tmp_files.key? image_path
            return @tmp_files[image_path]
          end
          tmp_image = ::Tempfile.create ['image-', image_format && %(.#{image_format})]
          tmp_image.binmode if (binary = image_format != 'svg')
          begin
            load_open_uri.open_uri(image_path, (binary ? 'rb' : 'r')) {|fd| tmp_image.write fd.read }
            tmp_image.close
            @tmp_files[image_path] = tmp_image.path
          rescue
            @tmp_files[image_path] = nil
            logger.warn %(could not retrieve remote image: #{image_path}; #{$!.message}) unless scratch?
            tmp_image.close
            unlink_tmp_file tmp_image.path
            nil
          end
        # handle case when image is a local file
        else
          node.normalize_system_path image_path, imagesdir, nil, target_name: 'image'
        end
      end

      # Resolve the path and sizing of the background image either from a document attribute or theme key.
      #
      # Returns the argument list for the image method if the document attribute or theme key is found. Otherwise,
      # nothing. The first argument in the argument list is the image path. If that value is nil, the background
      # image is disabled. The second argument is the options hash to specify the dimensions, such as width and fit.
      def resolve_background_image doc, theme, key, opts = {}
        if ::String === key
          image_path = (doc.attr key) || (from_theme = theme[(key.tr '-', '_').to_sym])
        else
          image_path = from_theme = theme[key]
        end
        if image_path
          if image_path == 'none'
            return []
          elsif (image_path.include? ':') && image_path =~ ImageAttributeValueRx
            image_attrs = (AttributeList.new $2).parse %w(alt width)
            if from_theme
              image_path = sub_attributes_discretely doc, $1
              image_relative_to = @themesdir
            else
              image_path = $1
              image_relative_to = true
            end
          elsif from_theme
            image_path = sub_attributes_discretely doc, image_path
            image_relative_to = @themesdir
          end

          image_path, image_format = ::Asciidoctor::Image.target_and_format image_path, image_attrs
          image_path = resolve_image_path doc, image_path, image_relative_to, image_format

          return unless image_path

          unless ::File.readable? image_path
            logger.warn %(#{key.to_s.tr '-_', ' '} not found or readable: #{image_path})
            return
          end

          [image_path, (resolve_image_options image_path, image_attrs, (opts.merge background: true, format: image_format))]
        end
      end

      def resolve_image_options image_path, image_attrs, opts = {}
        if (image_format = opts[:format] || (::Asciidoctor::Image.format image_path)) == 'svg'
          image_opts = {
            enable_file_requests_with_root: (::File.dirname image_path),
            enable_web_requests: allow_uri_read,
            cache_images: cache_uri,
            fallback_font_name: fallback_svg_font_name,
            format: 'svg',
          }
        else
          image_opts = {}
        end
        background = opts[:background]
        container_size = opts[:container_size] || (background ? [page_width, page_height] : [bounds.width, bounds.height])
        if image_attrs
          if background && (image_pos = image_attrs['position']) && (image_pos = resolve_background_position image_pos, nil)
            image_opts.update image_pos
          end
          if (image_fit = image_attrs['fit'] || (background ? 'contain' : nil))
            image_fit = 'contain' if image_format == 'svg' && image_fit == 'fill'
            container_width, container_height = container_size
            case image_fit
            when 'none'
              if (image_width = resolve_explicit_width image_attrs, container_width)
                image_opts[:width] = image_width
              end
            when 'scale-down'
              # NOTE if width and height aren't set in SVG, real width and height are computed after stretching viewbox to fit page
              if (image_width = resolve_explicit_width image_attrs, container_width) && image_width > container_width
                image_opts[:fit] = container_size
              elsif (image_size = intrinsic_image_dimensions image_path, image_format) &&
                  (image_width ? image_width * (image_size[:height].to_f / image_size[:width]) > container_height : (to_pt image_size[:width], :px) > container_width || (to_pt image_size[:height], :px) > container_height)
                image_opts[:fit] = container_size
              elsif image_width
                image_opts[:width] = image_width
              end
            when 'cover'
              # QUESTION should we take explicit width into account?
              if (image_size = intrinsic_image_dimensions image_path, image_format)
                if container_width * (image_size[:height].to_f / image_size[:width]) < container_height
                  image_opts[:height] = container_height
                else
                  image_opts[:width] = container_width
                end
              end
            when 'fill'
              image_opts[:width] = container_width
              image_opts[:height] = container_height
            else # when 'contain'
              image_opts[:fit] = container_size
            end
          elsif (image_width = resolve_explicit_width image_attrs, container_size[0])
            image_opts[:width] = image_width
          else # default to fit=contain if sizing is not specified
            image_opts[:fit] = container_size
          end
        else
          image_opts[:fit] = container_size
        end
        image_opts
      end

      # Resolves the explicit width as a PDF pt value if the value is specified in
      # absolute units, but defers resolving a percentage value until later.
      #
      # See resolve_explicit_width method for details about which attributes are considered.
      def preresolve_explicit_width attrs
        if attrs.key? 'pdfwidth'
          ((width = attrs['pdfwidth']).end_with? '%') ? width : (str_to_pt width)
        elsif attrs.key? 'scaledwidth'
          # NOTE the parser automatically appends % if value is unitless
          ((width = attrs['scaledwidth']).end_with? '%') ? width : (str_to_pt width)
        elsif attrs.key? 'width'
          # QUESTION should we honor percentage width value?
          to_pt attrs['width'].to_f, :px
        end
      end

      # Resolves the explicit width as a PDF pt value, if specified.
      #
      # Resolves the explicit width, first considering the pdfwidth attribute, then
      # the scaledwidth attribute and finally the width attribute. If the specified
      # value is in pixels, the value is scaled by 75% to perform approximate
      # CSS px to PDF pt conversion. If the resolved width is larger than the
      # max_width, the max_width value is returned.
      #--
      # QUESTION should we enforce positive result?
      def resolve_explicit_width attrs, max_width = bounds.width, opts = {}
        # QUESTION should we restrict width to max_width for pdfwidth?
        if attrs.key? 'pdfwidth'
          if (width = attrs['pdfwidth']).end_with? '%'
            (width.to_f / 100) * max_width
          elsif opts[:support_vw] && (width.end_with? 'vw')
            (width.chomp 'vw').extend ViewportWidth
          else
            str_to_pt width
          end
        elsif attrs.key? 'scaledwidth'
          # NOTE the parser automatically appends % if value is unitless
          if (width = attrs['scaledwidth']).end_with? '%'
            (width.to_f / 100) * max_width
          else
            str_to_pt width
          end
        elsif opts[:use_fallback] && (width = @theme.image_width)
          if ::Numeric === width
            width
          elsif (width = width.to_s).end_with? '%'
            (width.to_f / 100) * max_width
          elsif opts[:support_vw] && (width.end_with? 'vw')
            (width.chomp 'vw').extend ViewportWidth
          else
            str_to_pt width
          end
        elsif attrs.key? 'width'
          if (width = attrs['width']).end_with? '%'
            width = (width.to_f / 100) * max_width
          else
            width = to_pt width.to_f, :px
          end
          opts[:constrain_to_bounds] ? [max_width, width].min : width
        end
      end

      def resolve_background_position value, default_value = {}
        if value.include? ' '
          result = {}
          center = nil
          (value.split ' ', 2).each do |keyword|
            case keyword
            when 'left', 'right'
              result[:position] = keyword.to_sym
            when 'top', 'bottom'
              result[:vposition] = keyword.to_sym
            when 'center'
              center = true
            end
          end
          if center
            result[:position] ||= :center
            result[:vposition] ||= :center
            result
          elsif (result.key? :position) && (result.key? :vposition)
            result
          else
            default_value
          end
        elsif value == 'left' || value == 'right' || value == 'center'
          { position: value.to_sym, vposition: :center }
        elsif value == 'top' || value == 'bottom'
          { position: :center, vposition: value.to_sym }
        else
          default_value
        end
      end

      def resolve_top val
        if val.end_with? 'vh'
          page_height * (1 - (val.to_f / 100))
        elsif val.end_with? '%'
          @y - effective_page_height * (val.to_f / 100)
        else
          @y - (str_to_pt val)
        end
      end

      def add_link_to_image uri, image_info, image_opts
        image_width = image_info[:width]
        image_height = image_info[:height]

        case image_opts[:position]
        when :center
          image_x = bounds.left_side + (bounds.width - image_width) * 0.5
        when :right
          image_x = bounds.right_side - image_width
        else # :left or not set
          image_x = bounds.left_side
        end

        case image_opts[:vposition]
        when :top
          image_y = bounds.absolute_top
        when :center
          image_y = bounds.absolute_top - (bounds.height - image_height) * 0.5
        when :bottom
          image_y = bounds.absolute_bottom + image_height
        else
          image_y = y
        end unless (image_y = image_opts[:y])

        link_annotation [image_x, (image_y - image_height), (image_x + image_width), image_y], Border: [0, 0, 0], A: { Type: :Action, S: :URI, URI: uri.as_pdf }
      end

      def load_open_uri
        if @cache_uri && !(defined? ::OpenURI::Cache)
          # disable URI caching if library fails to load
          @cache_uri = false if (Helpers.require_library 'open-uri/cached', 'open-uri-cached', :warn).nil?
        end
        ::OpenURI
      end

      def remove_tmp_files
        @tmp_files.reject! {|_, path| path ? (unlink_tmp_file path) : true }
      end

      def unlink_tmp_file path
        ::File.unlink path if ::File.exist? path
        true
      rescue
        logger.warn %(could not delete temporary file: #{path}; #{$!.message}) unless scratch?
        false
      end

      def apply_subs_discretely doc, value, opts = {}
        imagesdir = doc.attr 'imagesdir'
        doc.set_attr 'imagesdir', @themesdir
        # FIXME: get sub_attributes to handle drop-line w/o a warning
        doc.set_attr 'attribute-missing', 'skip' unless (attribute_missing = doc.attr 'attribute-missing') == 'skip'
        value = value.gsub '\{', '\\\\\\{' if (escaped_attr_ref = value.include? '\{')
        value = doc.apply_subs value
        value = (value.split LF).delete_if {|line| SimpleAttributeRefRx.match? line }.join LF if opts[:drop_lines_with_unresolved_attributes] && (value.include? '{')
        value = value.gsub '\{', '{' if escaped_attr_ref
        doc.set_attr 'attribute-missing', attribute_missing unless attribute_missing == 'skip'
        if imagesdir
          doc.set_attr 'imagesdir', imagesdir
        else
          doc.remove_attr 'imagesdir'
        end
        value
      end

      def sub_attributes_discretely doc, value
        doc.set_attr 'attribute-missing', 'skip' unless (attribute_missing = doc.attr 'attribute-missing') == 'skip'
        value = doc.apply_subs value, [:attributes]
        doc.set_attr 'attribute-missing', attribute_missing unless attribute_missing == 'skip'
        value
      end

      def promote_author doc, idx = 1
        doc.remove_attr 'url' if (original_url = doc.attr 'url')
        email = nil
        if idx > 1
          original_attrs = AuthorAttributeNames.each_with_object({}) do |name, accum|
            accum[name] = doc.attr name
            if (val = doc.attr %(#{name}_#{idx}))
              doc.set_attr name, val
              # NOTE email holds url as well
              email = val if name == 'email'
            else
              doc.remove_attr name
            end
          end
          doc.set_attr 'url', ((email.include? '@') ? %(mailto:#{email}) : email) if email
          result = yield
          original_attrs.each {|name, val| val ? (doc.set_attr name, val) : (doc.remove_attr name) }
        else
          if (email = doc.attr 'email')
            doc.set_attr 'url', ((email.include? '@') ? %(mailto:#{email}) : email)
          end
          result = yield
        end
        if original_url
          doc.set_attr 'url', original_url
        elsif email
          doc.remove_attr 'url'
        end
        result
      end

      # NOTE assume URL is escaped (i.e., contains character references such as &amp;)
      def breakable_uri uri
        scheme, address = uri.split UriSchemeBoundaryRx, 2
        address, scheme = scheme, address unless address
        unless address.nil_or_empty?
          address = address.gsub UriBreakCharsRx, UriBreakCharRepl
          # NOTE require at least two characters after a break
          address.slice!(-2) if address[-2] == ZeroWidthSpace
        end
        %(#{scheme}#{address})
      end

      def consolidate_ranges nums
        if nums.size > 1
          prev = nil
          nums.each_with_object([]) {|num, accum|
            if prev && (prev.to_i + 1) == num.to_i
              accum[-1][1] = num
            else
              accum << [num]
            end
            prev = num
          }.map {|range| range.join '-' }
        else
          nums
        end
      end

      def resolve_pagenums val
        pgnums = []
        ((val.include? ',') ? (val.split ',') : (val.split ';')).each do |entry|
          if entry.include? '..'
            from, _, to = entry.partition '..'
            pgnums += ([from.to_i, 1].max..[to.to_i, 1].max).to_a
          else
            pgnums << entry.to_i
          end
        end

        pgnums
      end

      def get_char code
        (code.start_with? '\u') ? ([((code.slice 2, code.length).to_i 16)].pack 'U1') : code
      end

      # QUESTION move to prawn/extensions.rb?
      def init_scratch_prototype
        @save_state = nil
        @scratch_depth = 0
        # IMPORTANT don't set font before using Marshal, it causes serialization to fail
        @prototype = ::Marshal.load ::Marshal.dump self
        @prototype.state.store.info.data[:Scratch] = @prototype.text_formatter.scratch = true
        # NOTE we're now starting a new page each time, so no need to do it here
        #@prototype.start_new_page if @prototype.page_number == 0
      end

      def push_scratch doc
        if (@scratch_depth += 1) == 1
          @save_state = {
            catalog: {}.tap {|accum| doc.catalog.each {|k, v| accum[k] = v.dup } },
            attributes: doc.attributes.dup,
          }
        end
      end

      def pop_scratch doc
        if (@scratch_depth -= 1) == 0
          doc.catalog.replace @save_state[:catalog]
          doc.attributes.replace @save_state[:attributes]
          @save_state = nil
        end
      end
    end
  end
  Pdf = PDF unless const_defined? :Pdf, false
end
