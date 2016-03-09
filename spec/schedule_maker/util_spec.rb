require_relative 'spec_helper'

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

  describe '#get_element_from_hash' do
    hash = { 'badger' => 1, :badger => 2, 'mushroom' => 3, :snake => 4 }

    it 'Should return default if the hash does not contain the key' do
      expect(ScheduleMaker::Util.get_element_from_hash(hash, 'DOES_NOT_EXIST', 'DEFAULT')).to eq('DEFAULT')
    end

    it 'Should return value of symbol if symbol is in the hash' do
      expect(ScheduleMaker::Util.get_element_from_hash(hash, :badger, 'DEFAULT')).to eq(2)
    end

    it 'Should return value of string if string is in the hash' do
      expect(ScheduleMaker::Util.get_element_from_hash(hash, 'badger', 'DEFAULT')).to eq(1)
    end

    it 'Should return value of string if only the symbol is in the hash' do
      expect(ScheduleMaker::Util.get_element_from_hash(hash, :mushroom, 'DEFAULT')).to eq(3)
    end

    it 'Should return default if only the string is in the hash' do
      expect(ScheduleMaker::Util.get_element_from_hash(hash, 'snake', 'DEFAULT')).to eq('DEFAULT')
    end
  end

  describe '#midnight_today' do
    it 'Should return the time equal to midnight today' do
      now = Time.now
      midnight = Time.new(now.year, now.month, now.day)
      expect(ScheduleMaker::Util.midnight_today).to eq(midnight)
    end
  end

  describe '#dateparse' do
    it 'Should throw ArgumentError if input is nil' do
      expect { ScheduleMaker::Util.dateparse(nil) }.to raise_error(ArgumentError)
    end

    it 'Should throw ArgumentError if input is something other than a DateTime or String' do
      expect { ScheduleMaker::Util.dateparse({}) }.to raise_error(ArgumentError)
    end

    it 'Should throw ArgumentError if String is invalid' do
      expect { ScheduleMaker::Util.dateparse('badgers') }.to raise_error(ArgumentError)
    end

    it 'Should return an existing Time object' do
      date_obj = Time.utc(2001, 2, 3, 4, 5, 6)
      expect(ScheduleMaker::Util.dateparse(date_obj)).to eq(date_obj)
    end

    it 'Should convert a string to a Time object' do
      date_obj = Time.utc(2001, 2, 3, 4, 5, 6)
      date_str = '2001-02-03T04:05:06'
      expect(ScheduleMaker::Util.dateparse(date_str)).to eq(date_obj)
    end

    it 'Should be timezone aware converting strings' do
      date_str = '2001-02-03T04:05:06'
      expect(ScheduleMaker::Util.dateparse(date_str, 'UTC').hour).to eq(4)
      expect(ScheduleMaker::Util.dateparse(date_str, 'America/Chicago').hour).to eq(22)
      expect(ScheduleMaker::Util.dateparse(date_str, 'America/Los_Angeles').hour).to eq(20)
    end

    it 'Should be timezone aware converting Time objects' do
      date_obj = Time.utc(2001, 2, 3, 4, 5, 6)
      expect(ScheduleMaker::Util.dateparse(date_obj, 'UTC').hour).to eq(4)
      expect(ScheduleMaker::Util.dateparse(date_obj, 'America/Chicago').hour).to eq(22)
      expect(ScheduleMaker::Util.dateparse(date_obj, 'America/Los_Angeles').hour).to eq(20)
    end

    it 'Should be DST aware converting Time objects' do
      date_obj = Time.utc(2001, 7, 3, 4, 5, 6)
      expect(ScheduleMaker::Util.dateparse(date_obj, 'UTC').hour).to eq(4)
      expect(ScheduleMaker::Util.dateparse(date_obj, 'America/Chicago').hour).to eq(23)
      expect(ScheduleMaker::Util.dateparse(date_obj, 'America/Los_Angeles').hour).to eq(21)
    end
  end
end
