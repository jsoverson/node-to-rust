class Prawn::SVG::UrlLoader
  Error = Class.new(StandardError)

  attr_reader :enable_cache, :loaders

  def initialize(enable_cache: false, enable_web: true, enable_file_with_root: nil)
    @url_cache = {}
    @enable_cache = enable_cache

    @loaders = []
    loaders << Prawn::SVG::Loaders::Data.new
    loaders << Prawn::SVG::Loaders::Web.new if enable_web
    loaders << Prawn::SVG::Loaders::File.new(enable_file_with_root) if enable_file_with_root
  end

  def load(url)
    retrieve_from_cache(url) || perform_and_cache(url)
  end

  def add_to_cache(url, data)
    @url_cache[url] = data
  end

  def retrieve_from_cache(url)
    @url_cache[url]
  end

  private

  def perform_and_cache(url)
    data = perform(url)
    add_to_cache(url, data) if enable_cache
    data
  end

  def perform(url)
    try_each_loader(url) or raise Error, "No handler available for this URL scheme"
  end

  def try_each_loader(url)
    loaders.detect do |loader|
      data = loader.from_url(url)
      break data if data
    end
  end
end
