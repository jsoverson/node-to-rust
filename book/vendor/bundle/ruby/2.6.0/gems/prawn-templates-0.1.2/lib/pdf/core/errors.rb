module PDF
  module Core
    module Errors
      # This error is raised when object store fails to load a template file
      TemplateError = Class.new(StandardError)
    end
  end
end
