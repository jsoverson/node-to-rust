# frozen_string_literal: true

module Rouge
  module Themes
    # A variation on the pastie style from Pygments, customized for Asciidoctor PDF
    # See https://bitbucket.org/birkenfeld/pygments-main/src/default/pygments/styles/pastie.py
    class AsciidoctorPDFDefault < CSSTheme
      name 'asciidoctor_pdf_default'

      # Deviate from pastie here since our italic is actually a thinner font
      style Comment,                   fg: '#888888' #, italic: true
      style Comment::Preproc,          fg: '#cc0000', bold: true
      # Deviate from pastie here by not using a background color
      style Comment::Special,          fg: '#cc0000', bold: true #, bg: '#fff0f0'

      style Error,                     fg: '#a61717', bg: '#e3d2d2'
      style Generic::Error,            fg: '#aa0000'

      style Generic::Heading,          fg: '#333333'
      style Generic::Subheading,       fg: '#666666'

      style Generic::Deleted,          fg: '#000000', bg: '#ffdddd'
      style Generic::Inserted,         fg: '#000000', bg: '#ddffdd'

      style Generic::Emph,             italic: true
      style Generic::Strong,           bold: true

      style Generic::Lineno,           fg: '#888888'
      style Generic::Output,           fg: '#888888'
      style Generic::Prompt,           fg: '#555555'
      style Generic::Traceback,        fg: '#aa0000'

      style Keyword,                   fg: '#008800', bold: true
      style Keyword::Pseudo,           fg: '#008800'
      style Keyword::Type,             fg: '#888888', bold: true

      style Num,                       fg: '#0000dd', bold: true

      # Deviate from pastie here by not using background colors
      style Str,                       fg: '#dd2200' #, bg: '#fff0f0'
      style Str::Escape,               fg: '#0044dd' #, bg: '#fff0f0'
      style Str::Interpol,             fg: '#3333bb' #, bg: '#fff0f0'
      style Str::Other,                fg: '#22bb22' #, bg: '#f0fff0'
      style Str::Regex,                fg: '#008800' #, bg: '#fff0ff'
      style Str::Symbol,               fg: '#aa6600' #, bg: '#fff0f0'

      style Name::Attribute,           fg: '#336699'
      style Name::Builtin,             fg: '#003388'
      style Name::Class,               fg: '#bb0066', bold: true
      style Name::Constant,            fg: '#003366', bold: true
      style Name::Decorator,           fg: '#555555'
      style Name::Exception,           fg: '#bb0066', bold: true
      style Name::Function,            fg: '#0066bb', bold: true
      # Name::Label is used for built-in CSS properties in Rouge, so let's drop italics
      style Name::Label,               fg: '#336699' #, italic: true
      style Name::Namespace,           fg: '#bb0066', bold: true
      style Name::Property,            fg: '#336699', bold: true
      style Name::Tag,                 fg: '#bb0066', bold: true
      style Name::Variable,            fg: '#336699'
      style Name::Variable::Global,    fg: '#dd7700'
      style Name::Variable::Instance,  fg: '#3333bb'

      style Operator::Word,            fg: '#008800'

      style Text,                      {}
    end
  end
end
