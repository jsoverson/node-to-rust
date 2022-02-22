class Prawn::SVG::Elements::DepthFirstBase < Prawn::SVG::Elements::Base
  def initialize(document, source, parent_calls, state)
    super
    @base_calls = @calls = @parent_calls
  end

  def process
    parse_step
    apply_step(calls)
  rescue SkipElementQuietly
  rescue SkipElementError => e
    @document.warnings << e.message
  end

  def parse_and_apply
    raise "unsupported"
  end

  protected

  def parse_step
    extract_attributes_and_properties
    parse_standard_attributes
    parse
    parse_child_elements if container?
  end

  def apply_step(calls)
    @base_calls = @calls = calls
    apply_calls_from_standard_attributes
    apply
    apply_child_elements if container?
  end

  def parse_child_elements
    return unless source

    svg_child_elements.each do |elem|
      if element_class = Prawn::SVG::Elements::TAG_CLASS_MAPPING[elem.name.to_sym]
        child = element_class.new(@document, elem, @calls, state.dup)
        child.parse_step
        @children << child
      end
    end
  end

  def apply_child_elements
    @children.each do |child|
      child.apply_step(calls)
    end
  end
end
