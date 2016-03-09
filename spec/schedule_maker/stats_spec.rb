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

    it 'Should compute days correctly with no timezone offset' do
      sparse_schedule = [
        { start: '2016-04-17T00:00:00+00:00', end: '2016-04-18T00:00:00+00:00', length: 1, assignee: 'bob' }, # Sunday
        { start: '2016-04-29T00:00:00+00:00', end: '2016-04-30T00:00:00+00:00', length: 1, assignee: 'bob' }, # Friday
        { start: '2016-05-14T00:00:00+00:00', end: '2016-05-15T00:00:00+00:00', length: 1, assignee: 'bob' }, # Saturday
        { start: '2016-05-28T00:00:00+00:00', end: '2016-05-29T00:00:00+00:00', length: 1, assignee: 'bob' }, # Saturday
        { start: '2016-06-13T00:00:00+00:00', end: '2016-06-14T00:00:00+00:00', length: 1, assignee: 'bob' }, # Monday
        { start: '2016-06-27T00:00:00+00:00', end: '2016-06-28T00:00:00+00:00', length: 1, assignee: 'bob' }, # Monday
        { start: '2016-07-10T00:00:00+00:00', end: '2016-07-11T00:00:00+00:00', length: 1, assignee: 'bob' }, # Sunday
        { start: '2016-07-25T00:00:00+00:00', end: '2016-07-26T00:00:00+00:00', length: 1, assignee: 'bob' } # Monday
      ]
      participants = { 'bob' => { 'period_length' => 1 } }
      date = ScheduleMaker::Util.dateparse('2016-04-13T00:00:00')
      schedule = ScheduleMaker::Spec.sparse_schedule(sparse_schedule, date, participants: participants)
      stats = ScheduleMaker::Stats.stats(schedule, date)
      expect(stats['bob'][:sunday]).to eq(48)
      expect(stats['bob'][:monday]).to eq(72)
      expect(stats['bob'][:tuesday]).to eq(0)
      expect(stats['bob'][:wednesday]).to eq(0)
      expect(stats['bob'][:thursday]).to eq(0)
      expect(stats['bob'][:friday]).to eq(24)
      expect(stats['bob'][:saturday]).to eq(48)
      expect(stats['bob'][:weekday]).to eq(96)
      expect(stats['bob'][:weekend]).to eq(96)
    end

    it 'Should compute days correctly with timezone offset' do
      sparse_schedule = [
        { start: '2016-04-17T00:00:00+00:00', end: '2016-04-18T00:00:00+00:00', length: 1, assignee: 'bob' }, # Sat->Sun
        { start: '2016-04-29T00:00:00+00:00', end: '2016-04-30T00:00:00+00:00', length: 1, assignee: 'bob' }, # Thu->Fri
        { start: '2016-05-14T00:00:00+00:00', end: '2016-05-15T00:00:00+00:00', length: 1, assignee: 'bob' }, # Fri->Sat
        { start: '2016-05-28T00:00:00+00:00', end: '2016-05-29T00:00:00+00:00', length: 1, assignee: 'bob' }, # Fri->Sat
        { start: '2016-06-13T00:00:00+00:00', end: '2016-06-14T00:00:00+00:00', length: 1, assignee: 'bob' }, # Sun->Mon
        { start: '2016-06-27T00:00:00+00:00', end: '2016-06-28T00:00:00+00:00', length: 1, assignee: 'bob' }, # Sun->Mon
        { start: '2016-07-10T00:00:00+00:00', end: '2016-07-11T00:00:00+00:00', length: 1, assignee: 'bob' }, # Sat->Sun
        { start: '2016-07-25T00:00:00+00:00', end: '2016-07-26T00:00:00+00:00', length: 1, assignee: 'bob' }  # Sun->Mon
      ]
      participants = { 'bob' => { 'period_length' => 1, 'timezone' => 'America/Chicago' } }
      date = ScheduleMaker::Util.dateparse('2016-04-13T00:00:00')
      schedule = ScheduleMaker::Spec.sparse_schedule(sparse_schedule, date, participants: participants)
      stats = ScheduleMaker::Stats.stats(schedule, date)
      expect(stats['bob'][:sunday]).to eq(19*2 + 5*3)
      expect(stats['bob'][:monday]).to eq(19*3)
      expect(stats['bob'][:tuesday]).to eq(0)
      expect(stats['bob'][:wednesday]).to eq(0)
      expect(stats['bob'][:thursday]).to eq(5)
      expect(stats['bob'][:friday]).to eq(19*1 + 5*2)
      expect(stats['bob'][:saturday]).to eq(19*2 + 5*2)
      expect(stats['bob'][:weekday]).to eq(91)
      expect(stats['bob'][:weekend]).to eq(101)
    end
  end
end
