#
# Unfortunately, prawn mutates arguments passed in to it.
# When we make a copy of one of the call stacks, we need to make a deep
# duplicate of it so that the first time prawn mutates the arguments, it
# won't affect the subsequent calls.
#
module Prawn::SVG::Elements::CallDuplicator
  private

  def duplicate_calls(calls)
    calls.map { |call| duplicate_call(call) }
  end

  def duplicate_call(call)
    [call[0], duplicate_array(call[1]), duplicate_hash(call[2]), duplicate_calls(call[3])]
  end

  def duplicate_array(array)
    array.map do |value|
      case value
      when Array then duplicate_array(value)
      when Hash  then duplicate_hash(value)
      else            value
      end
    end
  end

  def duplicate_hash(hash)
    hash.each.with_object({}) do |(key, value), result|
      result[key] = case value
                    when Array then duplicate_array(value)
                    when Hash  then duplicate_hash(value)
                    else            value
                    end
    end
  end
end
