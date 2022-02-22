module Prawn
  module Text #:nodoc:
    def text_rendering_mode(mode = nil)
      if mode.nil?
        return defined?(@text_rendering_mode) && @text_rendering_mode || :fill
      end
      unless MODES.key?(mode)
        raise ArgumentError,
          "mode must be between one of #{MODES.keys.join(', ')} (#{mode})"
      end
      original_mode = text_rendering_mode

      if original_mode == :unknown
        original_mode = :fill
        add_content "\n#{MODES[:fill]} Tr"
      end

      if original_mode == mode
        yield
      else
        @text_rendering_mode = mode
        add_content "\n#{MODES[mode]} Tr"
        yield
        add_content "\n#{MODES[original_mode]} Tr"
        @text_rendering_mode = original_mode
      end
    end
  end
end
