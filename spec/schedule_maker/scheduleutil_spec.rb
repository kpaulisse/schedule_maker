require_relative 'spec_helper'

describe ScheduleMaker::ScheduleUtil do
  describe '#to_schedule' do
    rotation = [
      ScheduleMaker::Period.new('apple', 1),
      ScheduleMaker::Period.new('banana', 1),
      ScheduleMaker::Period.new('banana', 1),
      ScheduleMaker::Period.new('clementine', 2),
      ScheduleMaker::Period.new('banana', 1),
      ScheduleMaker::Period.new('apple', 1),
      ScheduleMaker::Period.new('apple', 1)
    ]

    rotation_2 = [
      ScheduleMaker::Period.new('apple', 1),
      ScheduleMaker::Period.new('banana', 2),
      ScheduleMaker::Period.new('apple', 1)
    ]

    it 'Should return a proper non-consolidated schedule' do
      result = ScheduleMaker::ScheduleUtil.to_schedule('2016-02-01T00:00:00', rotation)
      answer = [{ start: '2016-02-01T00:00:00+00:00',
                  end: '2016-02-02T00:00:00+00:00',
                  assignee: 'apple',
                  length: 1 },
                { start: '2016-02-02T00:00:00+00:00',
                  end: '2016-02-03T00:00:00+00:00',
                  assignee: 'banana',
                  length: 1 },
                { start: '2016-02-03T00:00:00+00:00',
                  end: '2016-02-04T00:00:00+00:00',
                  assignee: 'banana',
                  length: 1,
                  prev: 0.0 },
                { start: '2016-02-04T00:00:00+00:00',
                  end: '2016-02-05T00:00:00+00:00',
                  assignee: 'clementine',
                  length: 2 },
                { start: '2016-02-05T00:00:00+00:00',
                  end: '2016-02-06T00:00:00+00:00',
                  assignee: 'clementine',
                  length: 2 },
                { start: '2016-02-06T00:00:00+00:00',
                  end: '2016-02-07T00:00:00+00:00',
                  assignee: 'banana',
                  length: 1,
                  prev: 2.0 },
                { start: '2016-02-07T00:00:00+00:00',
                  end: '2016-02-08T00:00:00+00:00',
                  assignee: 'apple',
                  length: 1,
                  prev: 5.0 },
                { start: '2016-02-08T00:00:00+00:00',
                  end: '2016-02-09T00:00:00+00:00',
                  assignee: 'apple',
                  length: 1,
                  prev: 0.0 }]

      expect(result).to eq(answer)
    end

    it 'Should return a proper consolidated schedule' do
      result = ScheduleMaker::ScheduleUtil.to_schedule('2016-02-01T00:00:00', rotation, consolidated: true)
      answer = [{ start: '2016-02-01T00:00:00+00:00',
                  end: '2016-02-02T00:00:00+00:00',
                  assignee: 'apple',
                  length: 1 },
                { start: '2016-02-02T00:00:00+00:00',
                  end: '2016-02-04T00:00:00+00:00',
                  assignee: 'banana',
                  length: 2 },
                { start: '2016-02-04T00:00:00+00:00',
                  end: '2016-02-06T00:00:00+00:00',
                  assignee: 'clementine',
                  length: 2 },
                { start: '2016-02-06T00:00:00+00:00',
                  end: '2016-02-07T00:00:00+00:00',
                  assignee: 'banana',
                  length: 1,
                  prev: 2.0 },
                { start: '2016-02-07T00:00:00+00:00',
                  end: '2016-02-09T00:00:00+00:00',
                  assignee: 'apple',
                  length: 2,
                  prev: 5.0 }]
      expect(result).to eq(answer)
    end

    it 'Should handle fractional days' do
      result = ScheduleMaker::ScheduleUtil.to_schedule('2016-02-01T00:00:00', rotation_2, shift_length: 0.5)
      answer = [{ start: '2016-02-01T00:00:00+00:00',
                  end: '2016-02-01T12:00:00+00:00',
                  assignee: 'apple',
                  length: 1 },
                { start: '2016-02-01T12:00:00+00:00',
                  end: '2016-02-02T00:00:00+00:00',
                  assignee: 'banana',
                  length: 2 },
                { start: '2016-02-02T00:00:00+00:00',
                  end: '2016-02-02T12:00:00+00:00',
                  assignee: 'banana',
                  length: 2 },
                { start: '2016-02-02T12:00:00+00:00',
                  end: '2016-02-03T00:00:00+00:00',
                  assignee: 'apple',
                  length: 1,
                  prev: 1.0 }]
      expect(result).to eq(answer)
    end

    it 'Should handle fractional days in consolidated' do
      result = ScheduleMaker::ScheduleUtil.to_schedule('2016-02-01T00:00:00', rotation_2, shift_length: 0.5, consolidated: true)
      answer = [{ start: '2016-02-01T00:00:00+00:00',
                  end: '2016-02-01T12:00:00+00:00',
                  assignee: 'apple',
                  length: 1 },
                { start: '2016-02-01T12:00:00+00:00',
                  end: '2016-02-02T12:00:00+00:00',
                  assignee: 'banana',
                  length: 2 },
                { start: '2016-02-02T12:00:00+00:00',
                  end: '2016-02-03T00:00:00+00:00',
                  assignee: 'apple',
                  length: 1,
                  prev: 1.0 }]
      expect(result).to eq(answer)
    end

    it 'Should include correctly calculated :prev with respect to previous schedule (non-consolidated)' do
      options = { shift_length: 1, consolidated: false, prev_rotation: rotation_2 }
      result = ScheduleMaker::ScheduleUtil.to_schedule('2016-02-01T00:00:00', rotation_2, options)
      answer = [{ start: '2016-02-01T00:00:00+00:00',
                  end: '2016-02-02T00:00:00+00:00',
                  assignee: 'apple',
                  length: 1,
                  prev: 0.0 },
                { start: '2016-02-02T00:00:00+00:00',
                  end: '2016-02-03T00:00:00+00:00',
                  assignee: 'banana',
                  length: 2,
                  prev: 2.0 },
                { start: '2016-02-03T00:00:00+00:00',
                  end: '2016-02-04T00:00:00+00:00',
                  assignee: 'banana',
                  length: 2,
                  prev: 3.0 },
                { start: '2016-02-04T00:00:00+00:00',
                  end: '2016-02-05T00:00:00+00:00',
                  assignee: 'apple',
                  length: 1,
                  prev: 2.0 }]
      expect(result).to eq(answer)
    end

    it 'Should include correctly calculated :prev with respect to previous schedule (consolidated)' do
      options = { shift_length: 1, consolidated: true, prev_rotation: rotation_2 }
      result = ScheduleMaker::ScheduleUtil.to_schedule('2016-02-01T00:00:00', rotation_2, options)
      answer = [{ start: '2016-02-01T00:00:00+00:00',
                  end: '2016-02-02T00:00:00+00:00',
                  assignee: 'apple',
                  length: 1,
                  prev: 0.0 },
                { start: '2016-02-02T00:00:00+00:00',
                  end: '2016-02-04T00:00:00+00:00',
                  assignee: 'banana',
                  length: 2,
                  prev: 2.0 },
                { start: '2016-02-04T00:00:00+00:00',
                  end: '2016-02-05T00:00:00+00:00',
                  assignee: 'apple',
                  length: 1,
                  prev: 2.0 }]
      expect(result).to eq(answer)
    end

    it 'Should include correctly calculated :prev with shift_length != 1' do
      options = { shift_length: 0.5, consolidated: true, prev_rotation: rotation_2 }
      result = ScheduleMaker::ScheduleUtil.to_schedule('2016-02-01T00:00:00', rotation_2, options)
      answer = [{ start: '2016-02-01T00:00:00+00:00',
                  end: '2016-02-01T12:00:00+00:00',
                  assignee: 'apple',
                  length: 1,
                  prev: 0.0 },
                { start: '2016-02-01T12:00:00+00:00',
                  end: '2016-02-02T12:00:00+00:00',
                  assignee: 'banana',
                  length: 2,
                  prev: 1.0 },
                { start: '2016-02-02T12:00:00+00:00',
                  end: '2016-02-03T00:00:00+00:00',
                  assignee: 'apple',
                  length: 1,
                  prev: 1.0 }]
      expect(result).to eq(answer)
    end
  end
end
