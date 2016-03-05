require_relative 'spec_helper'

describe ScheduleMaker::Rotation do
  before(:all) do
    @rotations = ScheduleMaker::Spec.load_rotation
    @schedules = ScheduleMaker::Spec.load_schedule
    @start = ScheduleMaker::Util.dateparse('2016-01-01T00:00:00')
  end

  describe '#new' do
    it 'Should error out on an empty participants list' do
      expect { ScheduleMaker::Rotation.new({}) }.to raise_error(ArgumentError)
    end

    it 'Should construct a rotation with mixed Fixnum and Hash args' do
      dateobj = ScheduleMaker::Util.dateparse('2016-05-28T00:00:00')
      expect { ScheduleMaker::Rotation.new(@rotations['mixed_format'], 1, [], nil, start: dateobj) }.not_to raise_error
    end

    it 'Should construct a shift of the correct length with respect to :rotation_counter' do
      rotation = @rotations['small']

      rotation_1 = ScheduleMaker::Rotation.new(rotation, 1)
      expect(rotation_1.rotation_length).to eq(24)

      rotation_2 = ScheduleMaker::Rotation.new(rotation, 2)
      expect(rotation_2.rotation_length).to eq(48)

      rotation_3 = ScheduleMaker::Rotation.new(rotation, 3)
      expect(rotation_3.rotation_length).to eq(72)
    end
  end

  describe '#rotation_length' do
    it 'Should correctly compute rotation length for a simple rotation' do
      rotation = ScheduleMaker::Rotation.new(@rotations['small'])
      expect(rotation.rotation_length).to eq(24)
    end

    it 'Should correctly compute rotation length for a complex rotation' do
      rotation = ScheduleMaker::Rotation.new(@rotations['variety'])
      expect(rotation.rotation_length).to eq(6720)
    end
  end

  describe '#remove_from_schedule' do
    it 'Should correctly handle a complete removal' do
      dateobj = ScheduleMaker::Util.dateparse('2015-12-01T00:00:00')
      rotation = ScheduleMaker::Rotation.new(@rotations['mixed_format'], 1, [], nil, start: dateobj)
      expect(ScheduleMaker::Spec.include_shift_for(rotation.rotation, 'apple')).to be true
      expect(ScheduleMaker::Spec.include_shift_for(rotation.rotation, 'clementine')).to be false
      expect(rotation.rotation_length).to eq(20)
    end

    it 'Should correctly handle a rotation from which there are partial removals' do
      dateobj = ScheduleMaker::Util.dateparse('2016-01-01T00:00:00')
      rotation = ScheduleMaker::Rotation.new(@rotations['mixed_format'], 1, [], nil, start: dateobj)
      expect(rotation.rotation_length).to eq(22)
      expect(ScheduleMaker::Spec.include_shift_for(rotation.rotation, 'apple')).to be true
      expect(ScheduleMaker::Spec.include_shift_for(rotation.rotation, 'clementine')).to be true
    end

    it 'Should correctly handle a rotation from which there are no-op removals' do
      dateobj = ScheduleMaker::Util.dateparse('2016-02-01T00:00:00')
      rotation = ScheduleMaker::Rotation.new(@rotations['mixed_format'], 1, [], nil, start: dateobj)
      expect(rotation.rotation_length).to eq(24)
      expect(ScheduleMaker::Spec.include_shift_for(rotation.rotation, 'apple')).to be true
      expect(ScheduleMaker::Spec.include_shift_for(rotation.rotation, 'clementine')).to be true
    end
  end

  describe '#painscore' do
    it 'should properly compute pain score by summing squares of individual scores' do
      pain_class = { ScheduleMaker::DataModel::Spacing.new => 1 }
      rotation = ScheduleMaker::Rotation.new(@rotations['small'], 1, [], nil, { }, pain_class)
      painscore_answer = (2 * Math.exp(1))**2 + Math.exp(1)**2 + (Math.exp(1) + Math.exp(3))**2
      expect(rotation.painscore).to eq(painscore_answer.to_i)
    end

    it 'should return 0 when pain is false in all entries' do
      rotation = ScheduleMaker::Rotation.new(@rotations['small'])
      pain = {
        'apple'  => { score: Math.exp(1), pain: false },
        'banana' => { score: Math.exp(2), pain: false }
      }
      painscore_test = rotation.painscore([], {}, pain)
      expect(painscore_test).to eq(0)
    end

    it 'should not indicate pain if nobody is assigned prior to start date' do
      dateobj = ScheduleMaker::Util.dateparse('2016-01-01T00:00:00')
      schedule = ScheduleMaker::Spec.create_schedule(@schedules['tiny_datetest_1'])
      pain_class = { ScheduleMaker::DataModel::Spacing.new => 1 }
      rotation = ScheduleMaker::Rotation.new(@rotations['tiny_datetest'], 2, [], schedule, { start: dateobj }, pain_class)
      expect(rotation.pain['apple'][:pain]).to be false
      expect(rotation.pain['banana'][:pain]).to be false
      expect(rotation.pain['apple'][:score]).to eq(0)
      expect(rotation.pain['banana'][:score]).to eq(0)
    end

    it 'should indicate pain if somebody is assigned prior to start date' do
      dateobj = ScheduleMaker::Util.dateparse('2016-01-01T00:00:00')
      schedule = ScheduleMaker::Spec.create_schedule(@schedules['tiny_datetest_2'])
      pain_class = { ScheduleMaker::DataModel::Spacing.new => 1 }
      rotation = ScheduleMaker::Rotation.new(@rotations['tiny_datetest'], 2, [], schedule, { start: dateobj }, pain_class)
      expect(rotation.pain['apple'][:pain]).to be false
      expect(rotation.pain['banana'][:pain]).to be true
      expect(rotation.pain['apple'][:score]).to eq(0)
      expect(rotation.pain['banana'][:score]).to eq(Math.exp(10))
    end

    it 'should take into account the previous rotation when calculating pain' do
      prev = [
        ScheduleMaker::Period.new('apple', 1),
        ScheduleMaker::Period.new('elderberry', 1),
        ScheduleMaker::Period.new('fig', 4),
        ScheduleMaker::Period.new('apple', 1)
      ]
      schedule1 = ScheduleMaker::Spec.create_schedule(@schedules['small_1'])
      rotation1 = ScheduleMaker::Rotation.new(@rotations['small'], 1, [], schedule1)
      expect(rotation1.pain['apple'][:pain]).to be true
      expect(rotation1.pain['date'][:pain]).to be false
      expect(rotation1.pain['elderberry'][:pain]).to be false
      expect(rotation1.pain['fig'][:pain]).to be false

      schedule2 = ScheduleMaker::Spec.create_schedule(@schedules['small_1'])
      rotation2 = ScheduleMaker::Rotation.new(@rotations['small'], 1, prev, schedule2)
      expect(rotation2.pain['apple'][:pain]).to be true
      expect(rotation2.pain['date'][:pain]).to be false
      expect(rotation2.pain['elderberry'][:pain]).to be false
      expect(rotation2.pain['fig'][:pain]).to be true
    end
  end

  describe '#swap_legal?' do
    it 'Should refuse a swap if the index numbers match' do
      dateobj = ScheduleMaker::Util.dateparse('2016-01-01T00:00:00')
      schedule = ScheduleMaker::Spec.create_schedule(@schedules['simple_1'])
      rotation = ScheduleMaker::Rotation.new(@rotations['simple_1'], 2, [], schedule, start: dateobj)
      result = rotation.swap_legal?(1, 1)
      expect(result).to be false
    end

    it 'Should refuse a swap if the participant names match' do
      dateobj = ScheduleMaker::Util.dateparse('2016-01-01T00:00:00')
      schedule = ScheduleMaker::Spec.create_schedule(@schedules['simple_1'])
      rotation = ScheduleMaker::Rotation.new(@rotations['simple_1'], 2, [], schedule, start: dateobj)
      result = rotation.swap_legal?(0, 2)
      expect(result).to be false
    end

    it 'Should refuse a swap resulting in someone being assigned before they start' do
      dateobj = ScheduleMaker::Util.dateparse('2016-01-01T00:00:00')
      schedule = ScheduleMaker::Spec.create_schedule(@schedules['simple_1'])
      rotation = ScheduleMaker::Rotation.new(@rotations['simple_1'], 2, [], schedule, start: dateobj)
      rotation.override_participant_start_date_from_a_spec_test_only('banana', '2016-01-02T00:00:00')
      result = rotation.swap_legal?(0, 1)
      expect(result).to be false
    end

    it 'Should permit a swap resulting in someone being assigned after they start' do
      dateobj = ScheduleMaker::Util.dateparse('2016-01-01T00:00:00')
      schedule = ScheduleMaker::Spec.create_schedule(@schedules['simple_1'])
      rotation = ScheduleMaker::Rotation.new(@rotations['simple_1'], 2, [], schedule, start: dateobj)
      rotation.override_participant_start_date_from_a_spec_test_only('banana', '2016-01-03T00:00:00')
      result = rotation.swap_legal?(1, 2)
      expect(result).to be true
    end

    it 'Should calculate an illegal shift correctly when shift lengths are > 1' do
      dateobj = ScheduleMaker::Util.dateparse('2016-01-01T00:00:00')
      schedule = ScheduleMaker::Spec.create_schedule(@schedules['simple_2'])
      rotation = ScheduleMaker::Rotation.new(@rotations['simple_2'], 2, [], schedule, start: dateobj)
      rotation.override_participant_start_date_from_a_spec_test_only('banana', '2016-01-05T12:00:00')
      result = rotation.swap_legal?(2, 3)
      expect(result).to be false
    end

    it 'Should calculate a legal shift correctly when shift lengths are > 1' do
      dateobj = ScheduleMaker::Util.dateparse('2016-01-01T00:00:00')
      schedule = ScheduleMaker::Spec.create_schedule(@schedules['simple_2'])
      rotation = ScheduleMaker::Rotation.new(@rotations['simple_2'], 2, [], schedule, start: dateobj)
      rotation.override_participant_start_date_from_a_spec_test_only('banana', '2016-01-05T00:00:00')
      result = rotation.swap_legal?(2, 3)
      expect(result).to be true
    end

    it 'Should permit a swap where no start dates are considered' do
      dateobj = ScheduleMaker::Util.dateparse('2016-01-01T00:00:00')
      schedule = ScheduleMaker::Spec.create_schedule(@schedules['simple_1'])
      rotation = ScheduleMaker::Rotation.new(@rotations['simple_1'], 2, [], schedule, start: dateobj)
      result = rotation.swap_legal?(1, 2)
      expect(result).to be true
    end

    it 'Should have illegal swap correctly calculate day length > 1' do
      dateobj = ScheduleMaker::Util.dateparse('2016-01-01T00:00:00')
      schedule = ScheduleMaker::Spec.create_schedule(@schedules['simple_1'])
      rotation = ScheduleMaker::Rotation.new(@rotations['simple_1'], 2, [], schedule, start: dateobj, day_length: 7)
      rotation.override_participant_start_date_from_a_spec_test_only('banana', '2016-01-17T00:00:00')
      result = rotation.swap_legal?(2, 3)
      expect(result).to be false
    end

    it 'Should have legal swap correctly calculate day length > 1' do
      dateobj = ScheduleMaker::Util.dateparse('2016-01-01T00:00:00')
      schedule = ScheduleMaker::Spec.create_schedule(@schedules['simple_1'])
      rotation = ScheduleMaker::Rotation.new(@rotations['simple_1'], 2, [], schedule, start: dateobj, day_length: 7)
      rotation.override_participant_start_date_from_a_spec_test_only('banana', '2016-01-15T00:00:00')
      result = rotation.swap_legal?(2, 3)
      expect(result).to be true
    end

    it 'Should have illegal swap correctly calculate day length < 1' do
      dateobj = ScheduleMaker::Util.dateparse('2016-01-01T00:00:00')
      schedule = ScheduleMaker::Spec.create_schedule(@schedules['simple_1'])
      rotation = ScheduleMaker::Rotation.new(@rotations['simple_1'], 2, [], schedule, start: dateobj, day_length: 0.5)
      rotation.override_participant_start_date_from_a_spec_test_only('banana', '2016-01-02T15:00:00')
      result = rotation.swap_legal?(2, 3)
      expect(result).to be false
    end

    it 'Should have legal swap correctly calculate day length < 1' do
      dateobj = ScheduleMaker::Util.dateparse('2016-01-01T00:00:00')
      schedule = ScheduleMaker::Spec.create_schedule(@schedules['simple_1'])
      rotation = ScheduleMaker::Rotation.new(@rotations['simple_1'], 2, [], schedule, start: dateobj, day_length: 0.5)
      rotation.override_participant_start_date_from_a_spec_test_only('banana', '2016-01-02T00:00:00')
      result = rotation.swap_legal?(2, 3)
      expect(result).to be true
    end
  end

  describe 'Misc_Integration_Tests' do
    it 'Should not remove someone from the rotation just because they were not in the previous one' do
      previous_schedule = ScheduleMaker::Spec.create_schedule(@schedules['simple_1'])
      rotation = ScheduleMaker::Rotation.new(@rotations['mixed_format'], 1, previous_schedule)
      expect(ScheduleMaker::Spec.include_shift_for(rotation.rotation, 'apple')).to be true
      expect(ScheduleMaker::Spec.include_shift_for(rotation.rotation, 'clementine')).to be true
    end

    # This exists as an early warning to detect a change to the pain algorithm.
    # If you know that your change *did* change the pain algorithm, paste in the
    # correct values for the answer here.
    it 'Should iterate to known states with a known random number seed' do
      answer = [577, 306, 271, 271, 271, 294, 283]
      srand 42
      schedule = ScheduleMaker::Rotation.new(@rotations['medium'])
      result = []
      7.times do
        schedule = schedule.iterate
        result << schedule.painscore
      end
      expect(result).to eq(answer)
    end

    # There's a theoretical possibility that this won't pass, but it's small...
    it 'Should have a lower pain score after many iterations' do
      srand Random.new_seed
      schedule = ScheduleMaker::Rotation.new(@rotations['small'])
      initial_pain_score = schedule.painscore
      15.times { schedule = schedule.iterate }
      expect(schedule.painscore).to be < initial_pain_score
    end

    it 'Should handle start dates during the 2nd shift with previous schedule' do
      previous_schedule = ScheduleMaker::Spec.create_schedule(@schedules['simple_1'])
      start = ScheduleMaker::Util.dateparse('2015-12-18T00:00:00')
      rotation = ScheduleMaker::Rotation.new(@rotations['mixed_format'], 3, previous_schedule, nil, start: start)
      # clementine misses 1/3 of eligible shifts = 4
      expect(ScheduleMaker::Spec.include_shift_for(rotation.rotation, 'clementine')).to be true
      expect(rotation.rotation.count { |x| x.participant == 'clementine' }).to eq(8)
      expect(rotation.rotation_length).to eq(68)
    end

    it 'Should handle start dates during the 2nd shift without previous schedule' do
      start = ScheduleMaker::Util.dateparse('2015-12-18T00:00:00')
      rotation = ScheduleMaker::Rotation.new(@rotations['mixed_format'], 3, [], nil, start: start)
      # clementine misses 1/3 of eligible shifts = 4
      expect(rotation.rotation_length).to eq(68)
    end
  end
end
