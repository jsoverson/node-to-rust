# frozen_string_literal: true

######################################################################
#
# This file was copied from Prawn (manual/syntax_highlight.rb) and
# modified for use with Asciidoctor PDF.
#
# Since the file originates from the Prawn project, it shares the Prawn
# license. Thus, the file may be used under Matz's original licensing terms for
# Ruby, the GPLv2 license, or the GPLv3 license.
#
# Copyright (C) Felipe Doria
# Copyright (C) 2014-present OpenDevise Inc. and the Asciidoctor Project
#
######################################################################

require 'coderay'

# Registers a to_prawn method with CodeRay. The method returns an array of hashes to be
# used with Prawn::Text.formatted_text(array).
#
# Usage:
#
# CodeRay.scan(string, :ruby).to_prawn
#
module Asciidoctor
  module Prawn
    class CodeRayEncoder < ::CodeRay::Encoders::Encoder
      register_for :to_prawn

      # Manni theme from Pygments
      COLORS = {
        default: '333333',
        annotation: '9999FF',
        attribute_name: '4F9FCF',
        attribute_value: 'D44950',
        class: '00AA88',
        class_variable: '003333',
        color: 'FF6600',
        comment: '999999',
        constant: '336600',
        directive: '006699',
        doctype: '009999',
        entity: '999999',
        float: 'FF6600',
        function: 'CC00FF',
        important: '9999FF',
        inline_delimiter: 'EF804F',
        instance_variable: '003333',
        integer: 'FF6600',
        key: '006699',
        keyword: '006699',
        method: 'CC00FF',
        namespace: '00CCFF',
        predefined_type: '007788',
        regexp: '33AAAA',
        string: 'CC3300',
        symbol: 'FFCC33',
        tag: '2F6F9F',
        type: '007788',
        value: '336600',
      }

      LF = ?\n
      NoBreakSpace = ?\u00a0
      InnerIndent = LF + ' '
      GuardedIndent = ?\u00a0
      GuardedInnerIndent = LF + GuardedIndent

      def setup options
        super
        @out  = []
        @open = []
        # NOTE tracks whether text token begins at the start of a line
        @start_of_line = true
      end

      def text_token text, kind
        if text == LF
          @out << { text: text }
          @start_of_line = true
        # NOTE text is nil and kind is :error when CodeRay ends parsing on an error
        elsif text
          # NOTE add guard character to prevent Prawn from trimming indentation
          text[0] = GuardedIndent if @start_of_line && (text.start_with? ' ')
          text.gsub! InnerIndent, GuardedInnerIndent if text.include? InnerIndent

          # NOTE this optimization assumes we don't support/use background colors
          if text.rstrip.empty?
            @out << { text: text }
          else
            # QUESTION should we default to no color?
            @out << { text: text, color: (COLORS[kind] || COLORS[@open[-1]] || COLORS[:default]) }
          end
          @start_of_line = text.end_with? LF
        end
      end

      def begin_group kind
        @open << kind
      end

      def end_group _kind
        @open.pop
      end
    end
  end
end
