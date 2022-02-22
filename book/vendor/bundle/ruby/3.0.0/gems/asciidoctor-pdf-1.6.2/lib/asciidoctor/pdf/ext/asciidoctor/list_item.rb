# frozen_string_literal: true

# TODO: add these methods to Asciidoctor core
class Asciidoctor::ListItem
  # Check whether this list item has complex content (i.e., nested blocks other than an outline list).
  #
  # Return false if the list item contains no blocks or it contains a nested outline list. Otherwise, return true.
  def complex?
    !simple?
  end unless method_defined? :complex?

  # Check whether this list item has simple content (i.e., no nested blocks aside from an outline list).
  #
  # Return true if the list item contains no blocks or it contains a nested outline list. Otherwise, return false.
  def simple?
    @blocks.empty? || (@blocks.size == 1 && Asciidoctor::List === (blk = @blocks[0]) && blk.outline?)
  end unless method_defined? :simple?
end
