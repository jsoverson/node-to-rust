# frozen_string_literal: true

class Array
  def delete_all *entries
    entries.map {|entry| delete entry }.compact
  end unless method_defined? :delete_all

  def sum
    reduce(&:+)
  end unless method_defined? :sum
end
