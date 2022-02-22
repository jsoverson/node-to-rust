# frozen_string_literal: true

require 'delegate'

# A delegator that allows the size method to be used on the STDOUT object.
#
# The size of the content written to STDOUT cannot be measured normally. This
# class wraps the STDOUT object so the cumulative size of the content passed to
# the write method (while wrapped in this decorator) can be measured.
class QuantifiableStdout < SimpleDelegator
  attr_reader :size

  def initialize delegate
    @size = 0
    super
    delegate.binmode
  end

  def << content
    @size += content.to_s.bytesize
    super
  end

  def write content
    @size += content.to_s.bytesize
    super
  end
end
