require 'net/http'

module Prawn::SVG::Loaders
  class Web
    def from_url(url)
      uri = build_uri(url)

      if uri && %w(http https).include?(uri.scheme)
        perform_request(uri)
      end
    end

    private

    def build_uri(url)
      begin
        URI(url)
      rescue URI::InvalidURIError
      end
    end

    def perform_request(uri)
      Net::HTTP.get(uri)
    rescue => e
      raise Prawn::SVG::UrlLoader::Error, e.message
    end
  end
end
