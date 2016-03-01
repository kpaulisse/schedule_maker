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
  end
end
