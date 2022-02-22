# frozen_string_literal: true

########################################################################
#
# This file was copied from roman-numerals and modified for use with
# Asciidoctor PDF.
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
# Copyright (c) 2011 Andrew Vos
# Copyright (c) 2014 OpenDevise, Inc.
#
########################################################################

module Asciidoctor
  module PDF
    class RomanNumeral
      BaseDigits = {
        1 => 'I',
        4 => 'IV',
        5 => 'V',
        9 => 'IX',
        10 => 'X',
        40 => 'XL',
        50 => 'L',
        90 => 'XC',
        100 => 'C',
        400 => 'CD',
        500 => 'D',
        900 => 'CM',
        1000 => 'M',
      }

      def initialize initial_value, letter_case = nil
        initial_value ||= 1
        if ::Integer === initial_value
          @integer_value = initial_value
        else
          @integer_value = RomanNumeral.roman_to_int initial_value
          letter_case = :lower if letter_case.nil? && initial_value.upcase != initial_value
        end
        @letter_case = letter_case.nil? ? :upper : letter_case
      end

      def to_s
        to_r
      end

      def to_r
        if (int = @integer_value) < 1
          return int.to_s
        end
        roman = RomanNumeral.int_to_roman int
        @letter_case == :lower ? roman.downcase : roman
      end

      def to_i
        @integer_value
      end

      def odd?
        to_i.odd?
      end

      def even?
        to_i.even?
      end

      def next
        RomanNumeral.new @integer_value + 1, @letter_case
      end

      def next!
        @integer_value += 1
        self
      end

      def pred
        RomanNumeral.new @integer_value - 1, @letter_case
      end

      def empty?
        false
      end

      def self.int_to_roman value
        result = []
        BaseDigits.keys.reverse_each do |ival|
          while value >= ival
            value -= ival
            result << BaseDigits[ival]
          end
        end
        result.join
      end

      def self.roman_to_int value
        value = value.upcase
        result = 0
        BaseDigits.values.reverse_each do |rval|
          while value.start_with? rval
            offset = rval.length
            value = value[offset..offset]
            result += BaseDigits.key rval
          end
        end
        result
      end
    end
  end
end
