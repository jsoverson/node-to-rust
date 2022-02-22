# frozen_string_literal: true

module Asciidoctor
  class StubLogger
    class << self
      def info message = nil
        # ignore since this isn't a real logger
      end

      def info?
        false
      end

      def warn message = nil
        ::Kernel.warn %(asciidoctor: WARNING: #{message || (block_given? ? yield : '???')})
      end

      def error message = nil
        ::Kernel.warn %(asciidoctor: ERROR: #{message || (block_given? ? yield : '???')})
      end
    end
  end

  module Logging
    def logger
      StubLogger
    end

    def message_with_context text, _context = {}
      text
    end
  end
end
