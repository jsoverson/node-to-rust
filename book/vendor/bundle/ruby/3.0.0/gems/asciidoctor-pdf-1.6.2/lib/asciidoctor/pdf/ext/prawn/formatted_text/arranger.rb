# frozen_string_literal: true

Prawn::Text::Formatted::Arranger.prepend (Module.new do
  def initialize *_args
    super
    @dummy_text = ?\u0000
  end

  def next_string
    if (string = super) == @dummy_text
      def string.lstrip!; end
    end
    string
  end
end)
