class Prawn::SVG::Elements::Use < Prawn::SVG::Elements::Base
  attr_reader :referenced_element_class
  attr_reader :referenced_element_source

  def parse
    href = href_attribute
    if href.nil?
      raise SkipElementError, "use tag must have an href or xlink:href"
    end

    if href[0..0] != '#'
      raise SkipElementError, "use tag has an href that is not a reference to an id; this is not supported"
    end

    id = href[1..-1]
    referenced_element = @document.elements_by_id[id]

    if referenced_element
      @referenced_element_class = referenced_element.class
      @referenced_element_source = referenced_element.source
    else
      # Perhaps the element is defined further down in the document.  This is not recommended but still valid SVG,
      # so we'll support it with an exception case that's not particularly performant.
      raw_element = REXML::XPath.match(@document.root, %(//*[@id="#{id.gsub('"', '\"')}"])).first

      if raw_element
        @referenced_element_class = Prawn::SVG::Elements::TAG_CLASS_MAPPING[raw_element.name.to_sym]
        @referenced_element_source = raw_element
      end
    end

    if referenced_element_class.nil?
      raise SkipElementError, "no tag with ID '#{id}' was found, referenced by use tag"
    end

    state.inside_use = true

    @x = attributes['x']
    @y = attributes['y']
  end

  def container?
    true
  end

  def apply
    if @x || @y
      add_call_and_enter "translate", x_pixels(@x || 0), -y_pixels(@y || 0)
    end
  end

  def process_child_elements
    add_call "save"

    child = referenced_element_class.new(document, referenced_element_source, calls, state.dup)
    child.process

    add_call "restore"
  end
end
