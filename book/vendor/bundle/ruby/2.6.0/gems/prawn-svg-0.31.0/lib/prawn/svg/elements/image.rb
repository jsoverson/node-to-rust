class Prawn::SVG::Elements::Image < Prawn::SVG::Elements::Base
  class FakeIO
    def initialize(data)
      @data = data
    end
    def read
      @data
    end
    def rewind
    end
  end

  def parse
    require_attributes 'width', 'height'

    raise SkipElementQuietly if state.computed_properties.display == "none"

    @url = href_attribute
    if @url.nil?
      raise SkipElementError, "image tag must have an href or xlink:href"
    end

    x = x(attributes['x'] || 0)
    y = y(attributes['y'] || 0)
    width = x_pixels(attributes['width'])
    height = y_pixels(attributes['height'])

    raise SkipElementQuietly if width.zero? || height.zero?
    require_positive_value width, height

    @image = begin
      @document.url_loader.load(@url)
    rescue Prawn::SVG::UrlLoader::Error => e
      raise SkipElementError, "Error retrieving URL #{@url}: #{e.message}"
    end

    @aspect = Prawn::SVG::Calculators::AspectRatio.new(attributes['preserveAspectRatio'], [width, height], image_dimensions(@image))

    @clip_x = x
    @clip_y = y
    @clip_width = width
    @clip_height = height

    @width = @aspect.width
    @height = @aspect.height
    @x = x + @aspect.x
    @y = y - @aspect.y
  end

  def apply
    if @aspect.slice?
      add_call "save"
      add_call "rectangle", [@clip_x, @clip_y], @clip_width, @clip_height
      add_call "clip"
    end

    options = {:width => @width, :height => @height, :at => [@x, @y]}

    add_call "image", FakeIO.new(@image), options
    add_call "restore" if @aspect.slice?
  end

  def bounding_box
    [@x, @y, @x + @width, @y - @height]
  end

  protected

  def image_dimensions(data)
    handler = if data[0, 3].unpack("C*") == [255, 216, 255]
      Prawn::Images::JPG
    elsif data[0, 8].unpack("C*") == [137, 80, 78, 71, 13, 10, 26, 10]
      Prawn::Images::PNG
    else
      raise SkipElementError, "Unsupported image type supplied to image tag; Prawn only supports JPG and PNG"
    end

    image = handler.new(data)
    [image.width.to_f, image.height.to_f]
  end
end
