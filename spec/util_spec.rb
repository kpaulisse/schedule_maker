require 'spec_helper'

describe ScheduleMaker::Util do
  describe '#randomelement' do
    it 'Returns nil when the array is empty' do
      result = ScheduleMaker::Util.randomelement([])
      expect(result).to be_nil
    end

    it 'Returns the only element from a 1 element array' do
      result = ScheduleMaker::Util.randomelement(['badger'])
      expect(result).to eq('badger')
    end

    it 'Throws an error when a non-array is passed' do
      expect { ScheduleMaker::Util.randomelement('badger') }.to raise_error(ArgumentError)
    end

    it 'Properly returns a probabilistic element where initial probability was in range #1' do
      srand 42
      result = ScheduleMaker::Util.randomelement(%w(badger mushroom snake))
      expect(result).to eq('mushroom')
    end

    it 'Properly returns a probabilistic element where initial probability was in range #2' do
      srand 44
      result = ScheduleMaker::Util.randomelement(%w(badger mushroom snake))
      expect(result).to eq('badger')
    end

    it 'Properly returns a probabilistic element where initial probability was out of range' do
      srand 43
      result = ScheduleMaker::Util.randomelement(%w(badger mushroom snake))
      expect(result).to eq('badger')
    end
  end
end
