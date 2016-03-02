describe ScheduleMaker::Schedule do
  describe '#new' do
    it 'Should not throw an error if a string and fixnum are provided' do
      expect { ScheduleMaker::Schedule.new('apple' => 1, 'banana' => 1) }.not_to raise_error
    end

    it 'Should throw an error if an invalid participant name is given' do
      expect { ScheduleMaker::Schedule.new(true => 1, 'banana' => 1) }.to raise_error(ArgumentError)
      expect { ScheduleMaker::Schedule.new('' => 1, 'banana' => 1) }.to raise_error(ArgumentError)
    end

    it 'Should throw an error if an invalid shift length is given' do
      expect { ScheduleMaker::Schedule.new('apple' => 1, 'banana' => 0.5) }.to raise_error(ArgumentError)
      expect { ScheduleMaker::Schedule.new('apple' => 1, 'banana' => true) }.to raise_error(ArgumentError)
      expect { ScheduleMaker::Schedule.new('apple' => 1, 'banana' => nil) }.to raise_error(ArgumentError)
      expect { ScheduleMaker::Schedule.new('apple' => 1, 'banana' => 37) }.to raise_error(ArgumentError)
      expect { ScheduleMaker::Schedule.new('apple' => 1, 'banana' => -100) }.to raise_error(ArgumentError)
    end

    it 'Should throw an error if invalid participant hash is given' do
      expect { ScheduleMaker::Schedule.new(true) }.to raise_error(ArgumentError)
      expect { ScheduleMaker::Schedule.new('apple' => 1) }.to raise_error(ArgumentError)
      expect { ScheduleMaker::Schedule.new({}) }.to raise_error(ArgumentError)
    end

    it 'Should accept a hash with period_length and start date' do
      hash_1 = { 'apple' => 1, 'banana' => { 'period_length' => 1 } }
      hash_2 = { 'apple' => 1, 'banana' => { 'period_length' => 1, 'start' => '2016-05-28T00:00:00' } }
      expect { ScheduleMaker::Schedule.new(hash_1) }.not_to raise_error
      expect { ScheduleMaker::Schedule.new(hash_2) }.not_to raise_error
    end

    it 'Should throw an error if the period length is not specified in a hash' do
      hash_1 = { 'apple' => 1, 'banana' => {} }
      hash_2 = { 'apple' => 1, 'banana' => { 'start' => '2016-05-28T00:00:00' } }
      expect { ScheduleMaker::Schedule.new(hash_1) }.to raise_error(ArgumentError)
      expect { ScheduleMaker::Schedule.new(hash_2) }.to raise_error(ArgumentError)
    end

    it 'Should throw an error if an invalid period length is not specified in a hash' do
      hash_1 = { 'apple' => 1, 'banana' => { 'period_length' => 0 } }
      hash_2 = { 'apple' => 1, 'banana' => { 'period_length' => 37 } }
      hash_3 = { 'apple' => 1, 'banana' => { 'period_length' => 1.5 } }
      hash_4 = { 'apple' => 1, 'banana' => { 'period_length' => false } }
      hash_5 = { 'apple' => 1, 'banana' => { 'period_length' => 'Never' } }
      expect { ScheduleMaker::Schedule.new(hash_1) }.to raise_error(ArgumentError)
      expect { ScheduleMaker::Schedule.new(hash_2) }.to raise_error(ArgumentError)
      expect { ScheduleMaker::Schedule.new(hash_3) }.to raise_error(ArgumentError)
      expect { ScheduleMaker::Schedule.new(hash_4) }.to raise_error(ArgumentError)
      expect { ScheduleMaker::Schedule.new(hash_5) }.to raise_error(ArgumentError)
    end
  end
end
