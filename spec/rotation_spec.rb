describe ScheduleMaker::Rotation do
  before(:all) do
    @rotations = ScheduleMaker::Spec.load_rotation
    @rotation_trivial = ScheduleMaker::Rotation.new(@rotations['trivial'])
    @rotation_small = ScheduleMaker::Rotation.new(@rotations['small'])
    @rotation_variety = ScheduleMaker::Rotation.new(@rotations['variety'])

    @schedules = ScheduleMaker::Spec.load_schedule
    @schedule_small_1 = ScheduleMaker::Spec.create_schedule(@schedules['small_1'])
    @schedule_small_initial = ScheduleMaker::Spec.create_schedule(@schedules['small_initial'])
  end

  describe '#new' do
    it 'Should error out on an empty participants list' do
      expect { ScheduleMaker::Rotation.new({}) }.to raise_error(ArgumentError)
    end
  end

  describe '#period_lcm' do
    it 'Should correctly compute least common multiple for a simple rotation' do
      expect(@rotation_small.period_lcm).to eq(4)
    end

    it 'Should correctly compute least common multiple for a complex rotation' do
      expect(@rotation_variety.period_lcm).to eq(420)
    end
  end

  describe '#rotation_length' do
    it 'Should correctly compute rotation length for a simple rotation' do
      expect(@rotation_small.rotation_length).to eq(24)
    end

    it 'Should correctly compute rotation length for a complex rotation' do
      expect(@rotation_variety.rotation_length).to eq(6720)
    end
  end

  describe '#painscore' do
    it 'should properly compute pain score by summing squares of individual scores' do
      pain = {
        'apple'  => { score: Math.exp(1), pain: true },
        'banana' => { score: Math.exp(2), pain: true }
      }
      painscore_test = @rotation_small.painscore(false, pain)
      painscore_answer = Math.exp(1)**2 + Math.exp(2)**2
      expect(painscore_test).to eq(painscore_answer.to_i)
    end

    it 'should return 0 when pain is false in all entries' do
      pain = {
        'apple'  => { score: Math.exp(1), pain: false },
        'banana' => { score: Math.exp(2), pain: false }
      }
      painscore_test = @rotation_small.painscore(false, pain)
      expect(painscore_test).to eq(0)
    end

    it 'should return the correct pain score from a schedule override' do
      rotation = ScheduleMaker::Rotation.new(@rotations['small'], 1, [], @schedule_small_1)
      expect(rotation.painscore).to eq(1210)
    end
  end

  describe '#build_prev_rotation_hash' do
    it 'Should return empty hash map if incoming array is empty' do
      expect(@rotation_small.send(:build_prev_rotation_hash, [])).to eq({})
    end

    it 'Should properly construct hash map when a schedule is given' do
      answer = {
        'apple'      => 3,
        'banana'     => 2,
        'clementine' => 1,
        'date'       => 6,
        'elderberry' => 4,
        'fig'        => 14
      }
      result = @rotation_small.send(:build_prev_rotation_hash, @schedule_small_1)
      expect(result).to eq(answer)
    end
  end

  describe '#build_initial_participant_arrays' do
    it 'Should properly construct the hash map' do
      answer = {
        1 => [],
        2 => %w(date elderberry date elderberry),
        4 => ['fig']
      }
      4.times do
        answer[1].concat %w(apple banana clementine)
      end
      result = @rotation_small.send(:build_initial_participant_arrays)
      expect(result).to eq(answer)
    end
  end

  describe '#build_initial_schedule' do
    it 'Should properly construct an initial trivial schedule' do
      result = @rotation_trivial.send(:build_initial_schedule)
      answer = [
        ScheduleMaker::Period.new('apple', 1)
      ]
      expect(result).to eq(answer)
    end

    it 'Should properly construct an initial non-trivial schedule' do
      result = @rotation_small.send(:build_initial_schedule)
      expect(result).to eq(@schedule_small_initial)
    end
  end

  describe '#iterate' do
    it 'Should return the expected pain score with a known rotation' do
      schedule = @rotation_small.dup
      expect(schedule.painscore).to eq(556)
    end

    it 'Should iterate to known states with a known random number seed #1' do
      srand 75
      schedule = @rotation_small.dup

      schedule = schedule.iterate
      expect(schedule.painscore(true)).to eq(556)
    end

    it 'Should iterate to known states with a known random number seed #2' do
      srand 75
      schedule = @rotation_small.dup

      2.times { schedule = schedule.iterate }
      expect(schedule.painscore(true)).to eq(420)
    end

    it 'Should iterate to known states with a known random number seed #3' do
      srand 75
      schedule = @rotation_small.dup

      3.times { schedule = schedule.iterate }
      expect(schedule.painscore(true)).to eq(0)
    end

    # There's a theoretical possibility that this won't pass, but it's small...
    it 'Should have a lower pain score after many iterations' do
      srand Random.new_seed
      schedule = @rotation_small.dup
      25.times { schedule = schedule.iterate }
      expect(schedule.painscore).to be < @rotation_small.painscore
    end
  end
end
