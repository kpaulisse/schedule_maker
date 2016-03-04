require_relative 'spec_helper'

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

    it 'Should compute week days correctly with no timezone' do
      expect(@stats['apple'][:sunday]).to eq(0)
      expect(@stats['apple'][:monday]).to eq(0)
      expect(@stats['apple'][:tuesday]).to eq(24)
      expect(@stats['apple'][:wednesday]).to eq(24)
      expect(@stats['apple'][:thursday]).to eq(0)
      expect(@stats['apple'][:friday]).to eq(48)
      expect(@stats['apple'][:saturday]).to eq(0)
      expect(@stats['apple'][:weekend]).to eq(0)
      expect(@stats['apple'][:weekday]).to eq(96)
      expect(@stats['fig'][:sunday]).to eq(24)
      expect(@stats['fig'][:monday]).to eq(24)
      expect(@stats['fig'][:tuesday]).to eq(24)
      expect(@stats['fig'][:wednesday]).to eq(0)
      expect(@stats['fig'][:thursday]).to eq(0)
      expect(@stats['fig'][:friday]).to eq(0)
      expect(@stats['fig'][:saturday]).to eq(24)
      expect(@stats['fig'][:weekend]).to eq(48)
      expect(@stats['fig'][:weekday]).to eq(48)
    end

    it 'Should compute week days correctly with timezone' do
      schedule = ScheduleMaker::Schedule.new(@rotations['mixed_format_with_timezones'], start: @start, rotation_count: 1)
      stats = ScheduleMaker::Stats.stats(schedule, @start, schedule.rotation.participants)
      expect(stats['apple'][:sunday]).to eq(0)
      expect(stats['apple'][:monday]).to eq(5)
      expect(stats['apple'][:tuesday]).to eq(24)
      expect(stats['apple'][:wednesday]).to eq(19)
      expect(stats['apple'][:thursday]).to eq(10)
      expect(stats['apple'][:friday]).to eq(38)
      expect(stats['apple'][:saturday]).to eq(0)
      expect(stats['apple'][:weekend]).to eq(0)
      expect(stats['apple'][:weekday]).to eq(96)
      expect(stats['fig'][:sunday]).to eq(24)
      expect(stats['fig'][:monday]).to eq(24)
      expect(stats['fig'][:tuesday]).to eq(24)
      expect(stats['fig'][:wednesday]).to eq(11)
      expect(stats['fig'][:thursday]).to eq(0)
      expect(stats['fig'][:friday]).to eq(0)
      expect(stats['fig'][:saturday]).to eq(13)
      expect(stats['fig'][:weekend]).to eq(37)
      expect(stats['fig'][:weekday]).to eq(59)
    end
  end
end
