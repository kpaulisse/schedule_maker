require_relative '../spec_helper'

describe ScheduleMaker::DataModel::Weekdays do
  before(:all) do
    @rotations = ScheduleMaker::Spec.load_rotation
    @schedules = ScheduleMaker::Spec.load_schedule
    @start = ScheduleMaker::Util.dateparse('2016-01-01T00:00:00')
    @testobj = ScheduleMaker::DataModel::Weekdays.new
    @pain_class = { ScheduleMaker::DataModel::Weekdays.new => 1 }
  end

  describe '#cached_date' do
    it 'Should calculate and cache a date' do
      result = @testobj.cached_date(@start)
      start_integer = @start.strftime('%s')
      expect(result.strftime('%s')).to eq(start_integer)
      expect(@testobj.date_cache[@start]['UTC']).to eq(@start)
    end

    it 'Should calculate and cache a date in a different time zone' do
      result = @testobj.cached_date(@start, 'America/Chicago')
      start_integer = @start.strftime('%s')
      expect(result.strftime('%s')).to eq(start_integer)
      expect(@testobj.date_cache[@start]['America/Chicago']).to eq(@start)
    end
  end

  describe '#cached_hour' do
    it 'Should calculate the week day for a particular hour' do
      the_date = @testobj.cached_date(@start)
      result = @testobj.cached_hour(the_date)
      start_integer = @start.strftime('%s')
      expect(result).to eq(:friday)
      expect(@testobj.hour_cache[@start]['UTC']).to eq(:friday)
    end

    it 'Should calculate the week day for a particular hour in a different time zone' do
      the_date = @testobj.cached_date(@start, 'America/Chicago')
      result = @testobj.cached_hour(the_date, 'America/Chicago')
      expect(result).to eq(:thursday)
      expect(@testobj.hour_cache[@start]['America/Chicago']).to eq(:thursday)
    end
  end

  describe '#get_hours' do
    it 'Should correctly compute a shift in UTC' do
      start_time = @testobj.cached_date(@start)
      end_time = @testobj.cached_date(@start + 5)
      answer = {
        :sunday => 24, :monday => 24, :tuesday => 24, :wednesday => 0,
        :thursday => 0, :friday => 24, :saturday => 24,
        :weekend => 48, :weekday => 72
      }
      result = @testobj.get_hours(start_time, end_time)
      expect(result).to eq(answer)
    end

    it 'Should correctly compute a shift in another time zone' do
      start_time = @testobj.cached_date(@start, 'America/Chicago')
      end_time = @testobj.cached_date(@start + 5, 'America/Chicago')
      answer = {
        :sunday => 24, :monday => 24, :tuesday => 18, :wednesday => 0,
        :thursday => 6, :friday => 24, :saturday => 24,
        :weekend => 48, :weekday => 72
      }
      result = @testobj.get_hours(start_time, end_time, 'America/Chicago')
      expect(result).to eq(answer)
    end
  end

  describe '#pain' do
    it 'Should skip pain calculations if ruleset is empty' do
      ruleset = {}
      testobj = @testobj.dup
      testobj.apply_ruleset(ruleset)
      rotation = ScheduleMaker::Rotation.new(@rotations['simple_1'], 2, [], nil, {start: @start}, @pain_class)
      result = testobj.pain(rotation)
      expect(result['apple'][:skipped]).to be true
    end

    it 'Should compute pain array correctly' do
      ruleset = {
        :weekend => { penalty: 10, max_percent: 0.8, max_percent_cutoff: 4 },
        :weekday => { penalty: 0, max_percent: 1.1, max_percent_cutoff: 10 }
      }
      testobj = @testobj.dup
      testobj.apply_ruleset(ruleset)
      rotation = ScheduleMaker::Rotation.new(@rotations['simple_1'], 2, [], nil, {start: @start}, @pain_class)
      result = testobj.pain(rotation)
      expect(result['apple'][:sunday]).to eq(24)
      expect(result['apple'][:monday]).to eq(0)
      expect(result['apple'][:friday]).to eq(24)
      expect(result['apple'][:weekend]).to eq(24)
      expect(result['apple'][:weekday]).to eq(24)
      expect(result['apple'][:score].to_i).to eq(147)

      expect(result['banana'][:sunday]).to eq(0)
      expect(result['banana'][:monday]).to eq(24)
      expect(result['banana'][:saturday]).to eq(24)
      expect(result['banana'][:weekend]).to eq(24)
      expect(result['banana'][:weekday]).to eq(24)
      expect(result['banana'][:score].to_i).to eq(147)
    end

    it 'Should compute pain array correctly in another time zone' do
      ruleset = {
        :weekend => { penalty: 10, max_percent: 0.8, max_percent_cutoff: 4 },
        :weekday => { penalty: 0, max_percent: 1.1, max_percent_cutoff: 10 }
      }
      testobj = @testobj.dup
      testobj.apply_ruleset(ruleset)
      rotation = ScheduleMaker::Rotation.new(@rotations['simple_1_with_timezones'], 2, [], nil, {start: @start}, @pain_class)
      result = testobj.pain(rotation)
      expect(result['apple'][:sunday]).to eq(18)
      expect(result['apple'][:saturday]).to eq(6)
      expect(result['apple'][:monday]).to eq(0)
      expect(result['apple'][:thursday]).to eq(6)
      expect(result['apple'][:friday]).to eq(18)
      expect(result['apple'][:weekend]).to eq(24)
      expect(result['apple'][:weekday]).to eq(24)
      expect(result['apple'][:score].to_i).to eq(147)

      expect(result['banana'][:sunday]).to eq(11)
      expect(result['banana'][:saturday]).to eq(13)
      expect(result['banana'][:monday]).to eq(13)
      expect(result['banana'][:thursday]).to eq(0)
      expect(result['banana'][:friday]).to eq(0)
      expect(result['banana'][:weekend]).to eq(24)
      expect(result['banana'][:weekday]).to eq(24)
      expect(result['banana'][:score].to_i).to eq(147)
    end
  end

  describe '#valid?' do
    it 'Should return true if ruleset is empty' do
      ruleset = {}
      testobj = @testobj.dup
      testobj.apply_ruleset(ruleset)
      rotation = ScheduleMaker::Rotation.new(@rotations['simple_1'], 2, [], nil, {start: @start}, @pain_class)
      expect(testobj.valid?(rotation)).to be true
    end

    it 'Should enforce :max_percent in absence of :max_percent_cutoff' do
      ruleset = { weekend: { penalty: 10, max_percent: 0.4 } }
      testobj = @testobj.dup
      testobj.apply_ruleset(ruleset)
      rotation = ScheduleMaker::Rotation.new(@rotations['simple_1'], 2, [], nil, {start: @start}, @pain_class)
      result = testobj.valid?(rotation)
      expect(result).to be false
    end

    it 'Should enforce :max_percent when shifts are above :max_percent_cutoff' do
      ruleset = { weekend: { penalty: 10, max_percent: 0.4, max_percent_cutoff: 1 } }
      testobj = @testobj.dup
      testobj.apply_ruleset(ruleset)
      rotation = ScheduleMaker::Rotation.new(@rotations['simple_1'], 2, [], nil, {start: @start}, @pain_class)
      result = testobj.valid?(rotation)
      expect(result).to be false
    end

    it 'Should not enforce :max_percent when shifts are below :max_percent_cutoff' do
      ruleset = { weekend: { penalty: 10, max_percent: 0.4, max_percent_cutoff: 4 } }
      testobj = @testobj.dup
      testobj.apply_ruleset(ruleset)
      rotation = ScheduleMaker::Rotation.new(@rotations['simple_1'], 2, [], nil, {start: @start}, @pain_class)
      result = testobj.valid?(rotation)
      expect(result).to be true
    end

    it 'Should not fail if the percentage is below :max_percent' do
      ruleset = { weekend: { penalty: 10, max_percent: 0.7 } }
      testobj = @testobj.dup
      testobj.apply_ruleset(ruleset)
      rotation = ScheduleMaker::Rotation.new(@rotations['simple_1'], 2, [], nil, {start: @start}, @pain_class)
      result = testobj.valid?(rotation)
      expect(result).to be true
    end

    it 'Should OR the rules not AND them' do
      ruleset = { weekend: { max_percent: -1 }, weekday: { max_percent: 2 } }
      testobj = @testobj.dup
      testobj.apply_ruleset(ruleset)
      rotation = ScheduleMaker::Rotation.new(@rotations['simple_1'], 2, [], nil, {start: @start}, @pain_class)
      result = testobj.valid?(rotation)
      expect(result).to be false
    end

    it 'Should OR the rules not AND them (#2)' do
      ruleset = { weekend: { max_percent: 2 }, weekday: { max_percent: 2 } }
      testobj = @testobj.dup
      testobj.apply_ruleset(ruleset)
      rotation = ScheduleMaker::Rotation.new(@rotations['simple_1'], 2, [], nil, {start: @start}, @pain_class)
      result = testobj.valid?(rotation)
      expect(result).to be true
    end

    it 'Should OR the rules not AND them (#3)' do
      ruleset = { weekend: { max_percent: -1 }, weekday: { max_percent: -1 } }
      testobj = @testobj.dup
      testobj.apply_ruleset(ruleset)
      rotation = ScheduleMaker::Rotation.new(@rotations['simple_1'], 2, [], nil, {start: @start}, @pain_class)
      result = testobj.valid?(rotation)
      expect(result).to be false
    end
  end
end
