# frozen_string_literal: true

unless (defined? PDF::Core.pdf_object) == 'method'
  module PDF::Core
    alias pdf_object PdfObject
    module_function :pdf_object # rubocop:disable Style/AccessModifierDeclarations
  end
end
