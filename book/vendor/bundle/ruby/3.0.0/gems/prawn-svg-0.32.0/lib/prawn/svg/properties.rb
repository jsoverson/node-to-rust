class Prawn::SVG::Properties
  Config = Struct.new(:default, :inheritable?, :keywords, :keyword_restricted?, :attr, :ivar)

  EM = 16
  FONT_SIZES = {
    'xx-small' => EM / 4,
    'x-small'  => EM / 4 * 2,
    'small'    => EM / 4 * 3,
    'medium'   => EM / 4 * 4,
    'large'    => EM / 4 * 5,
    'x-large'  => EM / 4 * 6,
    'xx-large' => EM / 4 * 7
  }

  PROPERTIES = {
    "clip-path"        => Config.new("none", false, %w(inherit none)),
    "color"            => Config.new('', true),
    "display"          => Config.new("inline", false, %w(inherit inline none), true),
    "fill"             => Config.new("black", true, %w(inherit none currentColor)),
    "fill-opacity"     => Config.new("1", true),
    "fill-rule"        => Config.new("nonzero", true, %w(inherit nonzero evenodd)),
    "font-family"      => Config.new("sans-serif", true),
    "font-size"        => Config.new("medium", true, %w(inherit xx-small x-small small medium large x-large xx-large larger smaller)),
    "font-style"       => Config.new("normal", true, %w(inherit normal italic oblique), true),
    "font-variant"     => Config.new("normal", true, %w(inherit normal small-caps), true),
    "font-weight"      => Config.new("normal", true, %w(inherit normal bold 100 200 300 400 500 600 700 800 900), true), # bolder/lighter not supported
    "letter-spacing"   => Config.new("normal", true, %w(inherit normal)),
    "marker-end"       => Config.new("none", true, %w(inherit none)),
    "marker-mid"       => Config.new("none", true, %w(inherit none)),
    "marker-start"     => Config.new("none", true, %w(inherit none)),
    "opacity"          => Config.new("1", false),
    "overflow"         => Config.new('visible', false, %w(inherit visible hidden scroll auto), true),
    "stop-color"       => Config.new("black", false, %w(inherit none currentColor)),
    "stroke"           => Config.new("none", true, %w(inherit none currentColor)),
    "stroke-dasharray" => Config.new("none", true, %w(inherit none)),
    "stroke-linecap"   => Config.new("butt", true, %w(inherit butt round square), true),
    "stroke-opacity"   => Config.new("1", true),
    "stroke-width"     => Config.new("1", true),
    "text-anchor"      => Config.new("start", true, %w(inherit start middle end), true),
    'text-decoration'  => Config.new('none', true, %w(inherit none underline), true),
  }.freeze

  PROPERTIES.each do |name, value|
    value.attr = name.gsub("-", "_")
    value.ivar = "@#{value.attr}"
  end

  PROPERTY_CONFIGS = PROPERTIES.values
  NAMES = PROPERTIES.keys
  ATTR_NAMES = PROPERTIES.keys.map { |name| name.gsub('-', '_') }

  attr_accessor *ATTR_NAMES

  def load_default_stylesheet
    PROPERTY_CONFIGS.each do |config|
      instance_variable_set(config.ivar, config.default)
    end

    self
  end

  def set(name, value)
    if config = PROPERTIES[name.to_s.downcase]
      value = value.strip
      keyword = value.downcase
      keywords = config.keywords || ['inherit']

      if keywords.include?(keyword)
        value = keyword
      elsif config.keyword_restricted?
        value = config.default
      end

      instance_variable_set(config.ivar, value)
    end
  end

  def to_h
    PROPERTIES.each.with_object({}) do |(name, config), result|
      result[name] = instance_variable_get(config.ivar)
    end
  end

  def load_hash(hash)
    hash.each { |name, value| set(name, value) if value }
  end

  def compute_properties(other)
    PROPERTY_CONFIGS.each do |config|
      value = other.send(config.attr)

      if value && value != 'inherit'
        value = compute_font_size_property(value).to_s if config.attr == "font_size"
        instance_variable_set(config.ivar, value)

      elsif value.nil? && !config.inheritable?
        instance_variable_set(config.ivar, config.default)
      end
    end
  end

  def numerical_font_size
    # px = pt for PDFs
    FONT_SIZES[font_size] || font_size.to_f
  end

  private

  def compute_font_size_property(value)
    if value[-1] == "%"
      numerical_font_size * (value.to_f / 100.0)
    elsif value == 'larger'
      numerical_font_size + 4
    elsif value == 'smaller'
      numerical_font_size - 4
    elsif value.match(/(\d|\.)em\z/i)
      numerical_font_size * value.to_f
    elsif value.match(/(\d|\.)rem\z/i)
      value.to_f * EM
    else
      FONT_SIZES[value] || value.to_f
    end
  end
end
