require 'base64'

module Prawn::SVG::Loaders
  class Data
    REGEXP = %r[\Adata:image/(png|jpeg);base64(;[a-z0-9]+)*,]i

    def from_url(url)
      return if url[0..4].downcase != "data:"

      matches = url.match(REGEXP)
      if matches.nil?
        raise Prawn::SVG::UrlLoader::Error, "prawn-svg only supports base64-encoded image/png and image/jpeg data URLs"
      end

      Base64.decode64(matches.post_match)
    end
  end
end
