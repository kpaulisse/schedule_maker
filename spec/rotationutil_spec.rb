describe ScheduleMaker::RotationUtil do
  before(:all) do
    @rotations = ScheduleMaker::Spec.load_rotation
    @schedules = ScheduleMaker::Spec.load_schedule
    @start = ScheduleMaker::Util.dateparse('2016-01-01T00:00:00')
  end

  describe '#build_prev_rotation_hash' do
    it 'Should return empty hash map if incoming array is empty' do
      expect(ScheduleMaker::RotationUtil.build_prev_rotation_hash([])).to eq({})
    end

    it 'Should properly construct hash map when a schedule is given' do
      schedule = ScheduleMaker::Spec.create_schedule(@schedules['small_1'])
      answer = {
        'apple'      => 3,
        'banana'     => 2,
        'clementine' => 1,
        'date'       => 6,
        'elderberry' => 4,
        'fig'        => 14
      }
      result = ScheduleMaker::RotationUtil.build_prev_rotation_hash(schedule)
      expect(result).to eq(answer)
    end
  end

  describe '#build_initial_participant_arrays' do
    it 'Should properly construct the hash map' do
      rotation = ScheduleMaker::RotationUtil.prepare_participants(@rotations['small'], @start)
      answer = {
        1 => [],
        2 => %w(date elderberry date elderberry),
        4 => ['fig']
      }
      4.times do
        answer[1].concat %w(apple banana clementine)
      end
      result = ScheduleMaker::RotationUtil.build_initial_participant_arrays(rotation, 1)
      expect(result).to eq(answer)
    end
  end

  describe '#build_initial_schedule' do
    it 'Should properly construct an initial trivial schedule' do
      trivial_rotation = { 'apple' => 1 }
      participants = ScheduleMaker::RotationUtil.prepare_participants(trivial_rotation, @start)
      result = ScheduleMaker::RotationUtil.build_initial_schedule(participants, 1, @start, 1.0)
      answer = [
        ScheduleMaker::Period.new('apple', 1)
      ]
      expect(result).to eq(answer)
    end

    it 'Should properly construct an initial non-trivial schedule' do
      schedule = ScheduleMaker::Spec.create_schedule(@schedules['small_initial'])
      participants = ScheduleMaker::RotationUtil.prepare_participants(@rotations['small'], @start)
      result = ScheduleMaker::RotationUtil.build_initial_schedule(participants, 1, @start, 1.0)
      expect(result).to eq(schedule)
    end
  end

  describe '#calculate_shifts' do
    it 'Should calculate correct percentages for 1 shift with someone missing entire shift' do
      start = ScheduleMaker::Util.dateparse('2015-11-01T00:00:00')
      participants = ScheduleMaker::RotationUtil.prepare_participants(@rotations['mixed_format'], start)
      result = ScheduleMaker::RotationUtil.calculate_shifts(participants, 4, start, 1.0, 1)
      expect(result['apple']).to eq(4)      # No start date specified
      expect(result['clementine']).to eq(0) # Start date is after shift ends
      expect(result['date']).to eq(2)       # Start date is before shift starts; 2 day shifts
    end

    it 'Should calculate correct percentages for 2 shifts with someone missing entire shift' do
      start = ScheduleMaker::Util.dateparse('2015-06-01T00:00:00')
      participants = ScheduleMaker::RotationUtil.prepare_participants(@rotations['mixed_format'], start)
      result = ScheduleMaker::RotationUtil.calculate_shifts(participants, 4, start, 1.0, 2)
      expect(result['apple']).to eq(8)      # No start date specified
      expect(result['clementine']).to eq(0) # Start date is after shift ends
      expect(result['date']).to eq(4)       # Start date is before shift starts; 2 day shifts
    end

    it 'Should calculate correct percentages for 1 shift with partial miss' do
      start = ScheduleMaker::Util.dateparse('2014-12-31T00:00:00')
      participants = ScheduleMaker::RotationUtil.prepare_participants(@rotations['mixed_format'], start)
      result = ScheduleMaker::RotationUtil.calculate_shifts(participants, 4, start, 1.0, 1)
      expect(result['clementine']).to eq(0) # Start date is after shift ends
      expect(result['date']).to eq(1)       # Start date is half way through shift; 2 day shifts
    end

    it 'Should calculate correct percentages for 2 shifts with partial miss' do
      start = ScheduleMaker::Util.dateparse('2014-12-31T00:00:00')
      participants = ScheduleMaker::RotationUtil.prepare_participants(@rotations['mixed_format'], start)
      result = ScheduleMaker::RotationUtil.calculate_shifts(participants, 4, start, 1.0, 2)
      expect(result['clementine']).to eq(0) # Start date is after shift ends
      expect(result['date']).to eq(3)       # Start date is 1/4 of the way through shift; 2 day shifts
    end
  end

  describe '#calculate_rotation_length' do
    it 'Should return 0 for empty array' do
      result = ScheduleMaker::RotationUtil.calculate_rotation_length([])
      expect(result).to eq(0)
    end

    it 'Should properly calculate the rotation length' do
      schedule = ScheduleMaker::Spec.create_schedule(@schedules['small_1'])
      result = ScheduleMaker::RotationUtil.calculate_rotation_length(schedule)
      expect(result).to eq(24)
    end
  end

  describe '#participant_lcm' do
    it 'Should properly calculate LCM for a simple case' do
      participants = ScheduleMaker::RotationUtil.prepare_participants(@rotations['small'], @start)
      result = ScheduleMaker::RotationUtil.participant_lcm(participants)
      expect(result).to eq(4)
    end

    it 'Should properly calculate LCM for a complex case' do
      participants = ScheduleMaker::RotationUtil.prepare_participants(@rotations['variety'], @start)
      result = ScheduleMaker::RotationUtil.participant_lcm(participants)
      expect(result).to eq(420)
    end
  end
end
