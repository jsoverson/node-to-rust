# frozen_string_literal: true

class String
  def pred
    # integers
    ((Integer self) - 1).to_s
  rescue ::ArgumentError
    # chars (upper alpha, lower alpha, lower greek)
    ([65, 97, 945].include? ord) ? '0' : ([ord - 1].pack 'U1')
  end unless method_defined? :pred

  # If the string is ASCII only, convert it to a PDF LiteralString object. Otherwise, return self.
  def as_pdf
    ascii_only? ? (::PDF::Core::LiteralString.new encode ::Encoding::ASCII_8BIT) : self
  end

  # Convert the string to a serialized PDF object. If the string can be encoded as ASCII-8BIT, first convert it to a PDF
  # LiteralString object.
  def to_pdf_object
    ::PDF::Core.pdf_object as_pdf
  end
end
