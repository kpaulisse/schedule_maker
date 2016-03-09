require_relative '../../lib/schedule_maker'
require 'yaml'

module ScheduleMaker
  class Spec
    def self.load_rotation
      rotation_file = File.join(File.expand_path('../..', __FILE__), 'fixture', 'rotation.yaml')
      YAML.load_file(rotation_file)
    end

    def self.load_schedule
      rotation_file = File.join(File.expand_path('../..', __FILE__), 'fixture', 'schedule.yaml')
      YAML.load_file(rotation_file)
    end

    def self.create_schedule(schedule)
      raise "Invalid schedule (#{schedule.class} => #{schedule.inspect})" unless schedule.is_a?(Array)
      result = []
      schedule.each do |period|
        result << ScheduleMaker::Period.new(period.keys[0], period.values[0])
      end
      result
    end

    def self.include_shift_for(rotation, participant)
      rotation.each do |period|
        return true if period.participant == participant
      end
      false
    end

    def self.sparse_schedule(schedule_in, start, options = {})
      day_length = options.fetch(:day_length, 86400.0)
      safety_max = options.fetch(:safety_max, 365) # Prevent this from entering infinite loop
      participants = options.fetch(:participants, {})
      schedule = schedule_in.dup
      end_date = Util.dateparse(options.fetch(:end_date, schedule[schedule.size - 1][:end]))
      init_sched = []
      schedule_zero_start = ScheduleMaker::Util.dateparse(schedule[0][:start])
      iter = start.dup
      while iter < end_date
        if iter >= schedule_zero_start
          the_shift = schedule.shift
          date_diff = ScheduleMaker::Util.dateparse(the_shift[:end]) - ScheduleMaker::Util.dateparse(the_shift[:start])
          len = (1.0 * date_diff / day_length).to_i
          participants[the_shift[:assignee]] ||= { 'period_length' => len, 'timezone' => 'UTC' }
          len.times { |_c| init_sched << ScheduleMaker::Period.new(the_shift[:assignee], 1) }
          iter += day_length * len
          schedule_zero_start = schedule.empty? ? end_date : ScheduleMaker::Util.dateparse(schedule[0][:start])
        else
          participants['**unassigned**'] ||= { 'period_length' => 1, 'timezone' => 'UTC' }
          init_sched << ScheduleMaker::Period.new('**unassigned**', 1)
          iter += day_length
        end
      end
      fail 'ScheduleMaker::Spec::sparse_schedule failed to converge schedule!' unless schedule.empty?
      rotation = ScheduleMaker::Rotation.new(participants, start: start, init_sched: init_sched)
      ScheduleMaker::Schedule.new(participants, start: start, rotation: rotation)
    end
  end
end

describe ScheduleMaker::Spec do
  describe '#include_shift_for' do
    it 'Should return true when a shift for someone is included' do
      rotation = [
        ScheduleMaker::Period.new('alice', 1),
        ScheduleMaker::Period.new('bob', 1),
        ScheduleMaker::Period.new('charles', 1)
      ]
      expect(ScheduleMaker::Spec.include_shift_for(rotation, 'alice')).to be true
    end

    it 'Should return false when a shift for someone is included' do
      rotation = [
        ScheduleMaker::Period.new('alice', 1),
        ScheduleMaker::Period.new('bob', 1),
        ScheduleMaker::Period.new('charles', 1)
      ]
      expect(ScheduleMaker::Spec.include_shift_for(rotation, 'douglas')).to be false
    end
  end

  describe '#sparse_schedule' do
    it 'Should generate a correct sparse schedule with no specified end date' do
      date = ScheduleMaker::Util.dateparse('2016-01-01T00:00:00')
      sparse_schedule = [
        { start: '2016-01-13T00:00:00+00:00', end: '2016-01-14T00:00:00+00:00', length: 1, assignee: 'bob' },
        { start: '2016-01-29T00:00:00+00:00', end: '2016-01-30T00:00:00+00:00', length: 1, assignee: 'bob' }
      ]
      participants = { 'bob' => { 'period_length' => 1, 'timezone' => 'America/Chicago' } }
      schedule = ScheduleMaker::Spec.sparse_schedule(sparse_schedule, date, participants: participants)
      expect(schedule.rotation.rotation.size).to eq(29)
    end

    it 'Should generate a correct sparse schedule with a specified end date' do
      date = ScheduleMaker::Util.dateparse('2016-01-01T00:00:00')
      end_date = ScheduleMaker::Util.dateparse('2016-02-01T00:00:00')
      sparse_schedule = [
        { start: '2016-01-13T00:00:00+00:00', end: '2016-01-14T00:00:00+00:00', length: 1, assignee: 'bob' },
        { start: '2016-01-29T00:00:00+00:00', end: '2016-01-30T00:00:00+00:00', length: 1, assignee: 'bob' }
      ]
      participants = { 'bob' => { 'period_length' => 1, 'timezone' => 'America/Chicago' } }
      schedule = ScheduleMaker::Spec.sparse_schedule(sparse_schedule, date, participants: participants, end_date: end_date)
      expect(schedule.rotation.rotation.size).to eq(31)
    end

    it 'Should generate a correct sparse schedule with multiple participants' do
      date = ScheduleMaker::Util.dateparse('2016-01-01T00:00:00')
      sparse_schedule = [
        { start: '2016-01-13T00:00:00+00:00', end: '2016-01-14T00:00:00+00:00', length: 1, assignee: 'alice' },
        { start: '2016-01-29T00:00:00+00:00', end: '2016-01-30T00:00:00+00:00', length: 1, assignee: 'bob' }
      ]
      participants = { 'bob' => { 'period_length' => 1, 'timezone' => 'America/Chicago' } }
      schedule = ScheduleMaker::Spec.sparse_schedule(sparse_schedule, date, participants: participants)
      expect(schedule.rotation.rotation.size).to eq(29)
    end

    it 'Should generate a correct sparse schedule with no participants hash' do
      date = ScheduleMaker::Util.dateparse('2016-01-01T00:00:00')
      sparse_schedule = [
        { start: '2016-01-13T00:00:00+00:00', end: '2016-01-14T00:00:00+00:00', length: 1, assignee: 'alice' },
        { start: '2016-01-29T00:00:00+00:00', end: '2016-01-30T00:00:00+00:00', length: 1, assignee: 'bob' }
      ]
      schedule = ScheduleMaker::Spec.sparse_schedule(sparse_schedule, date)
      expect(schedule.rotation.rotation.size).to eq(29)
    end
  end
end
