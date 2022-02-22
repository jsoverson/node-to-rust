# frozen_string_literal: true

# TODO: add these methods to Asciidoctor core
class Asciidoctor::List
  # Check whether this list is an outline list (unordered or ordered).
  #
  # Return true if this list is an outline list. Otherwise, return false.
  def outline?
    @context == :ulist || @context == :olist
  end unless method_defined? :outline?

  # Check whether this list is nested inside the item of another list.
  #
  # Return true if the parent of this list is a list item. Otherwise, return false.
  def nested?
    Asciidoctor::ListItem === @parent
  end unless method_defined? :nested?

  # Get the level of this list within the broader outline list (unordered or ordered) structure.
  #
  # This method differs from the level property in that it considers all outline list ancestors.
  # It's important for selecting the marker for an unordered list.
  #
  # Return the 1-based level of this list within the outline list structure.
  def outline_level
    l = 1
    ancestor = self
    # FIXME: does not cross out of AsciiDoc table cell
    while (ancestor = ancestor.parent)
      l += 1 if Asciidoctor::List === ancestor && ancestor.outline?
    end
    l
  end unless method_defined? :outline_level
end
