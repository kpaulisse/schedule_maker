require 'spec_helper'

describe ScheduleMaker::Period do
  before(:all) do
    @period1 = ScheduleMaker::Period.new('badger', 1)
    @period2 = ScheduleMaker::Period.new('mushroom', 2)
  end

  describe '#new' do
    it 'Should return participant name from accessor' do
      expect(@period1.participant).to eq('badger')
      expect(@period2.participant).to eq('mushroom')
    end

    it 'Should return period length from accessor' do
      expect(@period1.period_length).to eq(1)
      expect(@period2.period_length).to eq(2)
    end
  end

  describe '#to_s' do
    it 'Should properly stringify single-period shifts' do
      expect(@period1.to_s).to eq('<badger: 1/1>')
    end

    it 'Should properly stringify multi-period shifts' do
      expect(@period2.to_s).to eq('<mushroom: 1/2><mushroom: 2/2>')
    end
  end

  describe '#inspect' do
    it 'Should properly inspectify single-period shifts' do
      expect(@period1.inspect).to eq("<ScheduleMaker::Period 'badger'=>'1'>")
    end

    it 'Should properly inspectify multi-period shifts' do
      expect(@period2.inspect).to eq("<ScheduleMaker::Period 'mushroom'=>'2'>")
    end
  end

  describe '#==' do
    it 'Should return true if two objects are equal' do
      obj1 = ScheduleMaker::Period.new('badger', 1)
      obj2 = ScheduleMaker::Period.new('badger', 1)
      expect(obj1).to eq(obj2)
    end

    it 'Should return false if comparison object is not of the right class' do
      obj1 = ScheduleMaker::Period.new('badger', 1)
      obj2 = 42
      expect(obj1).not_to eq(obj2)
    end

    it 'Should return false if participant name is different' do
      obj1 = ScheduleMaker::Period.new('badger', 1)
      obj2 = ScheduleMaker::Period.new('mushroom', 1)
      expect(obj1).not_to eq(obj2)
    end

    it 'Should return false if shift length is different' do
      obj1 = ScheduleMaker::Period.new('badger', 1)
      obj2 = ScheduleMaker::Period.new('badger', 2)
      expect(obj1).not_to eq(obj2)
    end
  end
end
