describe ScheduleMaker::Rotation do
  before(:all) do
    @rotations = ScheduleMaker::Spec.load_rotation
    @schedules = ScheduleMaker::Spec.load_schedule
  end

  describe '#new' do
    it 'Should error out on an empty participants list' do
      expect { ScheduleMaker::Rotation.new({}) }.to raise_error(ArgumentError)
    end

    it 'Should construct a rotation with mixed Fixnum and Hash args' do
      dateobj = ScheduleMaker::Util.dateparse('2016-05-28T00:00:00')
      expect { ScheduleMaker::Rotation.new(@rotations['mixed_format'], 1, [], nil, start: dateobj) }.not_to raise_error
    end
  end

  describe '#period_lcm' do
    it 'Should correctly compute least common multiple for a simple rotation' do
      rotation = ScheduleMaker::Rotation.new(@rotations['small'])
      expect(rotation.period_lcm).to eq(4)
    end

    it 'Should correctly compute least common multiple for a complex rotation' do
      rotation = ScheduleMaker::Rotation.new(@rotations['variety'])
      expect(rotation.period_lcm).to eq(420)
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
    it 'Should correctly compute rotation length for a rotation from which there are complete removals' do
      dateobj = ScheduleMaker::Util.dateparse('2012-01-01T00:00:00')
      rotation = ScheduleMaker::Rotation.new(@rotations['mixed_format'], 1, [], nil, start: dateobj)
      expect(rotation.rotation_length).to eq(20)
    end

    it 'Should correctly compute rotation length for a rotation from which there are partial removals' do
      dateobj = ScheduleMaker::Util.dateparse('2016-01-01T00:00:00')
      rotation = ScheduleMaker::Rotation.new(@rotations['mixed_format'], 1, [], nil, start: dateobj)
      expect(rotation.rotation_length).to eq(22)
    end

    it 'Should correctly compute rotation length for a rotation from which there are no-op removals' do
      dateobj = ScheduleMaker::Util.dateparse('2016-02-01T00:00:00')
      rotation = ScheduleMaker::Rotation.new(@rotations['mixed_format'], 1, [], nil, start: dateobj)
      expect(rotation.rotation_length).to eq(24)
    end
  end

  describe '#painscore' do
    it 'should properly compute pain score by summing squares of individual scores' do
      rotation = ScheduleMaker::Rotation.new(@rotations['small'])
      pain = {
        'apple'  => { score: Math.exp(1), pain: true },
        'banana' => { score: Math.exp(2), pain: true }
      }
      painscore_test = rotation.painscore(false, pain)
      painscore_answer = Math.exp(1)**2 + Math.exp(2)**2
      expect(painscore_test).to eq(painscore_answer.to_i)
    end

    it 'should return 0 when pain is false in all entries' do
      rotation = ScheduleMaker::Rotation.new(@rotations['small'])
      pain = {
        'apple'  => { score: Math.exp(1), pain: false },
        'banana' => { score: Math.exp(2), pain: false }
      }
      painscore_test = rotation.painscore(false, pain)
      expect(painscore_test).to eq(0)
    end

    it 'should return the correct pain score from a schedule override' do
      schedule = ScheduleMaker::Spec.create_schedule(@schedules['small_1'])
      rotation = ScheduleMaker::Rotation.new(@rotations['small'], 1, [], schedule)
      expect(rotation.painscore).to eq(1210)
    end

    it 'should not indicate pain if nobody is assigned prior to start date' do
      dateobj = ScheduleMaker::Util.dateparse('2016-01-01T00:00:00')
      schedule = ScheduleMaker::Spec.create_schedule(@schedules['tiny_datetest_1'])
      rotation = ScheduleMaker::Rotation.new(@rotations['tiny_datetest'], 2, [], schedule, start: dateobj)
      expect(rotation.pain['apple'][:pain]).to be false
      expect(rotation.pain['banana'][:pain]).to be false
      expect(rotation.pain['apple'][:score]).to eq(0)
      expect(rotation.pain['banana'][:score]).to eq(0)
    end

    it 'should indicate pain if somebody is assigned prior to start date' do
      dateobj = ScheduleMaker::Util.dateparse('2016-01-01T00:00:00')
      schedule = ScheduleMaker::Spec.create_schedule(@schedules['tiny_datetest_2'])
      rotation = ScheduleMaker::Rotation.new(@rotations['tiny_datetest'], 2, [], schedule, start: dateobj)
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

  describe '#build_prev_rotation_hash' do
    it 'Should return empty hash map if incoming array is empty' do
      rotation = ScheduleMaker::Rotation.new(@rotations['small'])
      expect(rotation.send(:build_prev_rotation_hash, [])).to eq({})
    end

    it 'Should properly construct hash map when a schedule is given' do
      rotation = ScheduleMaker::Rotation.new(@rotations['small'])
      schedule = ScheduleMaker::Spec.create_schedule(@schedules['small_1'])
      answer = {
        'apple'      => 3,
        'banana'     => 2,
        'clementine' => 1,
        'date'       => 6,
        'elderberry' => 4,
        'fig'        => 14
      }
      result = rotation.send(:build_prev_rotation_hash, schedule)
      expect(result).to eq(answer)
    end
  end

  describe '#build_initial_participant_arrays' do
    it 'Should properly construct the hash map' do
      rotation = ScheduleMaker::Rotation.new(@rotations['small'])
      answer = {
        1 => [],
        2 => %w(date elderberry date elderberry),
        4 => ['fig']
      }
      4.times do
        answer[1].concat %w(apple banana clementine)
      end
      result = rotation.send(:build_initial_participant_arrays)
      expect(result).to eq(answer)
    end
  end

  describe '#build_initial_schedule' do
    it 'Should properly construct an initial trivial schedule' do
      trivial_rotation = { 'apple' => 1 }
      rotation = ScheduleMaker::Rotation.new(trivial_rotation)
      result = rotation.send(:build_initial_schedule)
      answer = [
        ScheduleMaker::Period.new('apple', 1)
      ]
      expect(result).to eq(answer)
    end

    it 'Should properly construct an initial non-trivial schedule' do
      rotation = ScheduleMaker::Rotation.new(@rotations['small'])
      schedule = ScheduleMaker::Spec.create_schedule(@schedules['small_initial'])
      result = rotation.send(:build_initial_schedule)
      expect(result).to eq(schedule)
    end
  end

  describe '#equitable?' do
    it 'Should return true when rotation is equitable' do
      rotation = ScheduleMaker::Rotation.new(@rotations['small'])
      pain = {
        'apple'  => { spacing: [-1.0, 1.0, -1.0] },
        'banana' => { spacing: [-2.0, 0.0, 0.0] },
        'cherry' => { spacing: [1.0, -1.0, 0.0] }
      }
      result = rotation.send(:equitable?, pain)
      expect(result).to be true
    end

    it 'Should return false when rotation is not equitable' do
      rotation = ScheduleMaker::Rotation.new(@rotations['small'])
      pain = {
        'apple'  => { spacing: [-1.0, 2.0, 0.0] },
        'banana' => { spacing: [-2.0, 0.0, 0.0] },
        'cherry' => { spacing: [1.0, -1.0, 0.0] }
      }
      result = rotation.send(:equitable?, pain)
      expect(result).to be false
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

  describe '#iterate' do
    it 'Should return the expected pain score with a known rotation' do
      schedule = ScheduleMaker::Rotation.new(@rotations['small'])
      expect(schedule.painscore).to eq(556)
    end

    it 'Should iterate to known states with a known random number seed #1' do
      srand 75
      schedule = ScheduleMaker::Rotation.new(@rotations['small'])
      schedule = schedule.iterate
      expect(schedule.painscore(true)).to eq(556)
    end

    it 'Should iterate to known states with a known random number seed #2' do
      srand 75
      schedule = ScheduleMaker::Rotation.new(@rotations['small'])
      2.times { schedule = schedule.iterate }
      expect(schedule.painscore(true)).to eq(420)
    end

    it 'Should iterate to known states with a known random number seed #3' do
      srand 75
      schedule = ScheduleMaker::Rotation.new(@rotations['small'])
      3.times { schedule = schedule.iterate }
      expect(schedule.painscore(true)).to eq(0)
    end

    # There's a theoretical possibility that this won't pass, but it's small...
    it 'Should have a lower pain score after many iterations' do
      srand Random.new_seed
      schedule = ScheduleMaker::Rotation.new(@rotations['small'])
      initial_pain_score = schedule.painscore
      25.times { schedule = schedule.iterate }
      expect(schedule.painscore).to be < initial_pain_score
    end
  end
end
