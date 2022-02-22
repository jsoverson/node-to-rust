# frozen_string_literal: true

class Prawn::FontMetricCache::CacheEntry
  # workaround for https://github.com/prawnpdf/prawn/issues/1140
  def initialize font, options, size
    font = font.hash
    super
  end
end if Prawn::FontMetricCache::CacheEntry.members == [:font, :options, :string]
