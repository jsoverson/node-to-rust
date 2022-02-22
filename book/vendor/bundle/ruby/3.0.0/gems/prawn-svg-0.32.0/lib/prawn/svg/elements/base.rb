class Prawn::SVG::Elements::Base
  extend Forwardable

  include Prawn::SVG::Elements::CallDuplicator

  include Prawn::SVG::Calculators::Pixels

  include Prawn::SVG::Attributes::Transform
  include Prawn::SVG::Attributes::Opacity
  include Prawn::SVG::Attributes::ClipPath
  include Prawn::SVG::Attributes::Stroke
  include Prawn::SVG::Attributes::Space

  include Prawn::SVG::TransformParser

  PAINT_TYPES = %w(fill stroke)
  COMMA_WSP_REGEXP = Prawn::SVG::Elements::COMMA_WSP_REGEXP
  SVG_NAMESPACE = "http://www.w3.org/2000/svg"

  SkipElementQuietly = Class.new(StandardError)
  SkipElementError = Class.new(StandardError)
  MissingAttributesError = Class.new(SkipElementError)

  attr_reader :document, :source, :parent_calls, :base_calls, :state, :attributes, :properties
  attr_accessor :calls

  def_delegators :@document, :warnings
  def_delegator :@state, :computed_properties

  def initialize(document, source, parent_calls, state)
    @document = document
    @source = source
    @parent_calls = parent_calls
    @state = state
    @base_calls = @calls = []
    @attributes = {}
    @properties = Prawn::SVG::Properties.new

    if source && !state.inside_use
      id = source.attributes["id"]
      id = id.strip if id

      document.elements_by_id[id] = self if id && id != ''
    end
  end

  def process
    extract_attributes_and_properties
    parse_and_apply
  end

  def parse_and_apply
    parse_standard_attributes
    parse

    apply_calls_from_standard_attributes
    apply

    process_child_elements if container?

    append_calls_to_parent unless computed_properties.display == 'none'
  rescue SkipElementQuietly
  rescue SkipElementError => e
    @document.warnings << e.message
  end

  def name
    @name ||= source ? source.name : "???"
  end

  protected

  def parse
  end

  def apply
  end

  def bounding_box
  end

  def container?
    false
  end

  def drawable?
    !container?
  end

  def parse_standard_attributes
    parse_xml_space_attribute
  end

  def add_call(name, *arguments, **kwarguments)
    @calls << [name.to_s, arguments, kwarguments, []]
  end

  def add_call_and_enter(name, *arguments, **kwarguments)
    @calls << [name.to_s, arguments, kwarguments, []]
    @calls = @calls.last.last
  end

  def push_call_position
    @call_positions ||= []
    @call_positions << @calls
  end

  def pop_call_position
    @calls = @call_positions.pop
  end

  def append_calls_to_parent
    @parent_calls.concat(@base_calls)
  end

  def add_calls_from_element(other)
    @calls.concat duplicate_calls(other.base_calls)
  end

  def new_call_context_from_base
    old_calls = @calls
    @calls = @base_calls
    yield
    @calls = old_calls
  end

  def process_child_elements
    return unless source

    svg_child_elements.each do |elem|
      if element_class = Prawn::SVG::Elements::TAG_CLASS_MAPPING[elem.name.to_sym]
        add_call "save"

        child = element_class.new(@document, elem, @calls, state.dup)
        child.process

        add_call "restore"
      else
        @document.warnings << "Unknown tag '#{elem.name}'; ignoring"
      end
    end
  end

  def svg_child_elements
    source.elements.select do |elem|
      # To be strict, we shouldn't treat namespace-less elements as SVG, but for
      # backwards compatibility, and because it doesn't hurt, we will.
      elem.namespace == SVG_NAMESPACE || elem.namespace == ''
    end
  end

  def apply_calls_from_standard_attributes
    parse_transform_attribute_and_call
    parse_opacity_attributes_and_call
    parse_clip_path_attribute_and_call
    apply_colors
    parse_stroke_attributes_and_call
    apply_drawing_call
  end

  def apply_drawing_call
    return if state.disable_drawing || !drawable?

    fill   = computed_properties.fill != 'none'
    stroke = computed_properties.stroke != 'none'

    if fill
      command = stroke ? 'fill_and_stroke' : 'fill'

      if computed_properties.fill_rule == 'evenodd'
        add_call_and_enter(command, fill_rule: :even_odd)
      else
        add_call_and_enter(command)
      end
    elsif stroke
      add_call_and_enter('stroke')
    else
      add_call_and_enter('end_path')
    end
  end

  def apply_colors
    PAINT_TYPES.each do |type|
      color = properties.send(type)

      next if [nil, 'inherit', 'none'].include?(color)

      if color == 'currentColor'
        color = computed_properties.color
      end

      results = Prawn::SVG::Color.parse(color, document.gradients)

      success = results.detect do |result|
        case result
        when Prawn::SVG::Color::Hex
          add_call "#{type}_color", result.value
          true
        when Prawn::SVG::Elements::Gradient
          arguments = result.gradient_arguments(self)
          if arguments
            add_call "#{type}_gradient", **arguments
            true
          end
        end
      end

      # If we were unable to find a suitable color candidate,
      # we turn off this type of paint.
      if success.nil?
        computed_properties.set(type, 'none')
      end
    end
  end

  def clamp(value, min_value, max_value)
    [[value, min_value].max, max_value].min
  end

  def extract_attributes_and_properties
    if styles = document.element_styles[source]
      # TODO : implement !important, at the moment it's just ignored
      styles.each do |name, value, _important|
        @properties.set(name, value)
      end
    end

    @properties.load_hash(parse_css_declarations(source.attributes['style'] || ''))

    source.attributes.each do |name, value|
      # Properties#set returns nil if it's not a recognised property name
      @properties.set(name, value) or @attributes[name] = value
    end

    state.computed_properties.compute_properties(@properties)
  end

  def parse_css_declarations(declarations)
    # copied from css_parser
    declarations.gsub!(/(^[\s]*)|([\s]*$)/, '')

    output = {}
    declarations.split(/[\;$]+/m).each do |decs|
      if matches = decs.match(/\s*(.[^:]*)\s*\:\s*(.[^;]*)\s*(;|\Z)/i)
        property, value, _ = matches.captures
        output[property.downcase] = value
      end
    end
    output
  end

  def require_attributes(*names)
    missing_attrs = names - attributes.keys
    if missing_attrs.any?
      raise MissingAttributesError, "Must have attributes #{missing_attrs.join(", ")} on tag #{name}; skipping tag"
    end
  end

  def require_positive_value(*args)
    if args.any? {|arg| arg.nil? || arg <= 0}
      raise SkipElementError, "Invalid attributes on tag #{name}; skipping tag"
    end
  end

  def extract_element_from_url_id_reference(value, expected_type = nil)
    matches = value.strip.match(/\Aurl\(\s*#(\S+)\s*\)\z/i) if value
    element = document.elements_by_id[matches[1]] if matches
    element if element && (expected_type.nil? || element.name == expected_type)
  end

  def href_attribute
    attributes['xlink:href'] || attributes['href']
  end
end
