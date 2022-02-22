# encoding: utf-8
#
# Copyright September 2016, Jesse Doyle. All rights reserved.
#
# This is free software. Please see the LICENSE and COPYING files for details.

describe Prawn::Icon::Base do
  describe 'FONTDIR' do
    it 'returns the data/fonts directory' do
      path = File.expand_path '../../..', __FILE__
      path = File.join path, 'data/fonts'
      expect(Prawn::Icon::Base::FONTDIR).to eq(path)
    end
  end
end
