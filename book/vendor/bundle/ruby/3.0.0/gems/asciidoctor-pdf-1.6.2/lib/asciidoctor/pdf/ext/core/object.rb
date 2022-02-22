# frozen_string_literal: true

class Object
  # Convert the object to a serialized PDF object.
  def to_pdf_object
    ::PDF::Core.pdf_object self
  end
end
