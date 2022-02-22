class Prawn::SVG::Elements::Text < Prawn::SVG::Elements::DepthFirstBase
  private

  # This class doesn't represent an element in the SVG document; it's here
  # to hold together text information.  Because of this, we overload the
  # parse_step and apply_step methods, and bypass all the normal processing
  # of the element, delegating it to our root text component.

  def parse_step
    state.text = Prawn::SVG::Elements::TextComponent::TextState.new

    @text_root = Prawn::SVG::Elements::TextComponent.new(document, source, nil, state.dup)
    @text_root.parse_step

    reintroduce_trailing_and_leading_whitespace
  end

  def apply_step(calls)
    @base_calls = @calls = calls
    add_call_and_enter "text_group"
    @text_root.apply_step(@calls)
  end

  def drawable?
    false
  end

  def reintroduce_trailing_and_leading_whitespace
    printables = []
    built_printable_queue(printables, @text_root)

    remove_whitespace_only_printables_and_start_and_end(printables)
    remove_printables_that_are_completely_empty(printables)
    apportion_leading_and_trailing_spaces(printables)
  end

  def built_printable_queue(queue, component)
    component.commands.each do |command|
      case command
      when Prawn::SVG::Elements::TextComponent::Printable
        queue << command
      else
        built_printable_queue(queue, command)
      end
    end
  end

  def remove_whitespace_only_printables_and_start_and_end(printables)
    printables.pop   while printables.last  && printables.last.text.empty?
    printables.shift while printables.first && printables.first.text.empty?
  end

  def remove_printables_that_are_completely_empty(printables)
    printables.reject! do |printable|
      printable.text.empty? && !printable.trailing_space? && !printable.leading_space?
    end
  end

  def apportion_leading_and_trailing_spaces(printables)
    printables.each_cons(2) do |a, b|
      if a.text.empty?
        # Empty strings can only get a leading space from the previous non-empty text,
        # and never get a trailing space
      elsif a.trailing_space?
        a.text += ' '
      elsif b.leading_space?
        b.text = " #{b.text}"
      end
    end
  end
end
