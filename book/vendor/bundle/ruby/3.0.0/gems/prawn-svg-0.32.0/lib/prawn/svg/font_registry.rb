class Prawn::SVG::FontRegistry
  DEFAULT_FONT_PATHS = [
    "/Library/Fonts",
    "/System/Library/Fonts",
    "#{ENV["HOME"]}/Library/Fonts",
    "/usr/share/fonts/truetype",
    "/mnt/c/Windows/Fonts", # Bash on Ubuntu on Windows
  ]

  @font_path = DEFAULT_FONT_PATHS.select { |path| Dir.exist?(path) }

  def initialize(font_families)
    @font_families = font_families
  end

  def installed_fonts
    merge_external_fonts
    @font_families
  end

  def correctly_cased_font_name(name)
    merge_external_fonts
    @font_case_mapping[name.downcase]
  end

  def load(family, weight = nil, style = nil)
    Prawn::SVG::CSS::FontFamilyParser.parse(family).detect do |name|
      name = name.gsub(/\s{2,}/, ' ').downcase

      font = Prawn::SVG::Font.new(name, weight, style, font_registry: self)
      break font if font.installed?
    end
  end

  private

  def merge_external_fonts
    if @font_case_mapping.nil?
      self.class.load_external_fonts unless self.class.external_font_families
      @font_families.merge!(self.class.external_font_families) do |key, v1, v2|
       v1
      end
      @font_case_mapping = @font_families.keys.each.with_object({}) do |key, result|
        result[key.downcase] = key
      end
    end
  end

  class << self
    attr_reader :external_font_families, :font_path

    def load_external_fonts
      @external_font_families = {}

      external_font_paths.each do |filename|
        ttf = Prawn::SVG::TTF.new(filename)
        if ttf.family
          subfamily = (ttf.subfamily || "normal").gsub(/\s+/, "_").downcase.to_sym
          subfamily = :normal if subfamily == :regular
          (external_font_families[ttf.family] ||= {})[subfamily] ||= filename
        end
      end
    end

    private

    def external_font_paths
      font_path
        .uniq
        .flat_map { |path| Dir["#{path}/**/*"] }
        .uniq
        .select { |path| File.file?(path) }
    end
  end
end
