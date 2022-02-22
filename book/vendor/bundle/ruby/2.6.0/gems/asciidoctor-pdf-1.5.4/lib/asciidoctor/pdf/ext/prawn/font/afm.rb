# frozen_string_literal: true

class Prawn::Font::AFM
  include ::Asciidoctor::Logging

  FALLBACK_CHARS = {
    ?\u200b => '',
    ?\u202f => ?\u00a0,
    ?\u2009 => ' ',
    ?\u25e6 => '-',
    ?\u25aa => ?\u00b7,
  }

  remove_method :normalize_encoding

  # Patch normalize_encoding method to handle conversion more gracefully.
  #
  # Any valid utf-8 characters that cannot be encoded to windows-1252 are
  # replaced with the logic "not" symbol and a warning is issued identifying
  # the text that cannot be converted.
  def normalize_encoding text
    text.encode 'windows-1252', fallback: FALLBACK_CHARS
  rescue ::Encoding::UndefinedConversionError
    logger.warn %(The following text could not be fully converted to the Windows-1252 character set:
#{text.gsub(/^/, '| ').rstrip}) if logger.info? && !@document.scratch?
    text.encode 'windows-1252', undef: :replace, replace: ?\u00ac
  rescue ::Encoding::InvalidByteSequenceError
    raise Prawn::Errors::IncompatibleStringEncoding,
        'Your document includes text which is not compatible with the Windows-1252 character set.
If you need full UTF-8 support, use TTF fonts instead of the built-in PDF (AFM) fonts.'
  end
end
