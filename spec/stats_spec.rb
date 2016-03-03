describe ScheduleMaker::Stats do
  before(:all) do
    @rotations = ScheduleMaker::Spec.load_rotation
    @start = ScheduleMaker::Util.dateparse('2016-01-01T00:00:00')
    @schedule = ScheduleMaker::Schedule.new(@rotations['mixed_format'], start: @start, rotation_count: 1)
    @stats = ScheduleMaker::Stats.stats(@schedule, @start)
  end

  describe '#stats' do
    it 'Should have ScheduleMaker::Stats.stats and ScheduleMaker::Schedule.stats in agreement' do
      stats_from_schedule = @schedule.stats
      expect(@stats).to eq(stats_from_schedule)
    end

    it 'Should compute the per-assignee days correctly' do
      expect(@stats['apple'][:days]).to eq(4)
      expect(@stats['date'][:days]).to eq(4)
      expect(@stats['fig'][:days]).to eq(4)
    end

    it 'Should compute the per-assignee shifts correctly' do
      expect(@stats['apple'][:shifts]).to eq(4)
      expect(@stats['date'][:shifts]).to eq(2)
      expect(@stats['fig'][:shifts]).to eq(1)
    end

    it 'Should compute the per-assignee minimum shift length correctly' do
      expect(@stats['apple'][:min_shift]).to eq(1)
      expect(@stats['date'][:min_shift]).to eq(2)
      expect(@stats['fig'][:min_shift]).to eq(4)
    end

    it 'Should compute the per-assignee maximum shift length correctly' do
      expect(@stats['apple'][:max_shift]).to eq(1)
      expect(@stats['date'][:max_shift]).to eq(2)
      expect(@stats['fig'][:max_shift]).to eq(4)
    end

    it 'Should compute the per-assignee spacing array correctly' do
      expect(@stats['apple'][:spacing]).to eq([3, 9, 4])
      expect(@stats['date'][:spacing]).to eq([8])
      expect(@stats['fig'][:spacing]).to eq([])
    end
  end
end
