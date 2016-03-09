require_relative '../spec_helper'

describe ScheduleMaker::DataModel::Weekdays do
  before(:all) do
    @rotations = ScheduleMaker::Spec.load_rotation
    @schedules = ScheduleMaker::Spec.load_schedule
    @start = ScheduleMaker::Util.dateparse('2016-01-01T00:00:00')
  end

  describe '#cached_hour' do
    it 'Should calculate the week day for a particular hour (first hit)' do
      testobj = ScheduleMaker::DataModel::Weekdays.new
      expect(testobj.cached_hour(@start)).to eq(:friday)
    end

    it 'Should calculate the week day for a particular hour (from the cache)' do
      testobj = ScheduleMaker::DataModel::Weekdays.new
      _foo = testobj.cached_hour(@start)
      expect(testobj.cached_hour(@start)).to eq(:friday)
      expect(testobj.hour_cache[@start.to_i]['UTC']).to eq(:friday)
    end

    it 'Should calculate the week day for a particular hour in a different time zone (first hit)' do
      testobj = ScheduleMaker::DataModel::Weekdays.new
      expect(testobj.cached_hour(@start, 'America/Chicago')).to eq(:thursday)
      expect(testobj.cached_hour(@start + 6*3600, 'America/Chicago')).to eq(:friday)
    end

    it 'Should calculate the week day for a particular hour in a different time zone (from the cache)' do
      testobj = ScheduleMaker::DataModel::Weekdays.new
      _foo = testobj.cached_hour(@start, 'America/Chicago')
      expect(testobj.cached_hour(@start, 'America/Chicago')).to eq(:thursday)
      expect(testobj.hour_cache[@start.to_i]['America/Chicago']).to eq(:thursday)

      _foo = testobj.cached_hour(@start + 6*3600, 'America/Chicago')
      expect(testobj.cached_hour(@start + 6*3600, 'America/Chicago')).to eq(:friday)
      expect(testobj.hour_cache[@start.to_i + 6*3600]['America/Chicago']).to eq(:friday)
    end

  end

  describe '#get_hours' do
    it 'Should correctly handle a single hour in UTC' do
      testobj = ScheduleMaker::DataModel::Weekdays.new
      start_time = ScheduleMaker::Util.dateparse('2016-01-01T00:00:00')
      end_time = ScheduleMaker::Util.dateparse('2016-01-01T01:00:00')
      answer = {
        sunday: 0, monday: 0, tuesday: 0, wednesday: 0,
        thursday: 0, friday: 1, saturday: 0,
        weekend: 0, weekday: 1
      }
      result = testobj.get_hours(start_time, end_time)
      expect(result).to eq(answer)
    end

    it 'Should correctly handle a single hour in another time zone' do
      testobj = ScheduleMaker::DataModel::Weekdays.new
      start_time = ScheduleMaker::Util.dateparse('2016-01-01T00:00:00')
      end_time = ScheduleMaker::Util.dateparse('2016-01-01T01:00:00')
      answer = {
        sunday: 0, monday: 0, tuesday: 0, wednesday: 0,
        thursday: 1, friday: 0, saturday: 0,
        weekend: 0, weekday: 1
      }
      result = testobj.get_hours(start_time, end_time, 'America/Chicago')
      expect(result).to eq(answer)
    end

    it 'Should correctly handle a single day in UTC' do
      testobj = ScheduleMaker::DataModel::Weekdays.new
      start_time = ScheduleMaker::Util.dateparse('2016-01-01T00:00:00')
      end_time = ScheduleMaker::Util.dateparse('2016-01-02T00:00:00')
      answer = {
        sunday: 0, monday: 0, tuesday: 0, wednesday: 0,
        thursday: 0, friday: 24, saturday: 0,
        weekend: 0, weekday: 24
      }
      result = testobj.get_hours(start_time, end_time)
      expect(result).to eq(answer)
    end

    it 'Should correctly handle a single day in another time zone' do
      testobj = ScheduleMaker::DataModel::Weekdays.new
      start_time = ScheduleMaker::Util.dateparse('2016-01-01T00:00:00')
      end_time = ScheduleMaker::Util.dateparse('2016-01-02T00:00:00')
      answer = {
        sunday: 0, monday: 0, tuesday: 0, wednesday: 0,
        thursday: 6, friday: 18, saturday: 0,
        weekend: 0, weekday: 24
      }
      result = testobj.get_hours(start_time, end_time, 'America/Chicago')
      expect(result).to eq(answer)
    end

    it 'Should correctly an end time not falling directly on an hour' do
      testobj = ScheduleMaker::DataModel::Weekdays.new
      start_time = ScheduleMaker::Util.dateparse('2016-01-01T00:00:00')
      end_time = ScheduleMaker::Util.dateparse('2016-01-01T12:34:56')
      answer = {
        sunday: 0, monday: 0, tuesday: 0, wednesday: 0,
        thursday: 0, friday: 13, saturday: 0,
        weekend: 0, weekday: 13
      }
      result = testobj.get_hours(start_time, end_time)
      expect(result).to eq(answer)
    end

    it 'Should correctly compute a shift in UTC' do
      testobj = ScheduleMaker::DataModel::Weekdays.new
      start_time = @start
      end_time = @start + (5 * 86400)
      answer = {
        sunday: 24, monday: 24, tuesday: 24, wednesday: 0,
        thursday: 0, friday: 24, saturday: 24,
        weekend: 48, weekday: 72
      }
      result = testobj.get_hours(start_time, end_time)
      expect(result).to eq(answer)
    end

    it 'Should correctly compute a shift in another time zone' do
      testobj = ScheduleMaker::DataModel::Weekdays.new
      start_time = @start
      end_time = @start + (5 * 86400)
      answer = {
        sunday: 24, monday: 24, tuesday: 18, wednesday: 0,
        thursday: 6, friday: 24, saturday: 24,
        weekend: 48, weekday: 72
      }
      result = testobj.get_hours(start_time, end_time, 'America/Chicago')
      expect(result).to eq(answer)
    end
  end

  describe '#pain' do
    it 'Should skip pain calculations if ruleset is empty' do
      testobj = ScheduleMaker::DataModel::Weekdays.new({})
      rotation = ScheduleMaker::Rotation.new(@rotations['simple_1'], count: 2, start: @start)
      result = testobj.pain(rotation)
      expect(result['apple'][:skipped]).to be true
    end

    it 'Should compute pain score correctly (UTC)' do
      start = ScheduleMaker::Util.dateparse('2016-02-29T00:00:00')
      ruleset = {
        weekend: { penalty: 10, max_percent: 0.8, max_percent_cutoff: 4 },
        weekday: { penalty: 0, max_percent: 1.1, max_percent_cutoff: 10 }
      }
      testobj = ScheduleMaker::DataModel::Weekdays.new(ruleset)
      rotation = ScheduleMaker::Rotation.new(@rotations['simple_1'], count: 3, start: start)
      result = testobj.pain(rotation)
      expect(result['apple'][:score].to_i).to eq(0)
      expect(result['banana'][:score].to_i).to eq(27)
    end

    it 'Should compute pain score correctly (Another Time Zone)' do
      start = ScheduleMaker::Util.dateparse('2016-02-29T00:00:00')
      ruleset = {
        weekend: { penalty: 10, max_percent: 0.8, max_percent_cutoff: 4 },
        weekday: { penalty: 0, max_percent: 1.1, max_percent_cutoff: 10 }
      }
      testobj = ScheduleMaker::DataModel::Weekdays.new(ruleset)
      rotation = ScheduleMaker::Rotation.new(@rotations['simple_1_with_timezones'], count: 3, start: start)
      result = testobj.pain(rotation)
      expect(result['apple'][:score].to_i).to eq(1)
      expect(result['banana'][:score].to_i).to eq(27)
    end

    it 'Should count days correctly (UTC)' do
      start = ScheduleMaker::Util.dateparse('2016-02-29T00:00:00')
      testobj = ScheduleMaker::DataModel::Weekdays.new
      rotation = ScheduleMaker::Rotation.new(@rotations['simple_1'], count: 3, start: start)
      result = testobj.pain(rotation, force_calc: true)
      expect(result['apple'][:sunday].to_i).to eq(0)
      expect(result['apple'][:monday].to_i).to eq(24)
      expect(result['apple'][:tuesday].to_i).to eq(0)
      expect(result['apple'][:wednesday].to_i).to eq(24)
      expect(result['apple'][:thursday].to_i).to eq(0)
      expect(result['apple'][:friday].to_i).to eq(24)
      expect(result['apple'][:saturday].to_i).to eq(0)
      expect(result['apple'][:weekday].to_i).to eq(72)
      expect(result['apple'][:weekend].to_i).to eq(0)
      expect(result['banana'][:sunday].to_i).to eq(0)
      expect(result['banana'][:monday].to_i).to eq(0)
      expect(result['banana'][:tuesday].to_i).to eq(24)
      expect(result['banana'][:wednesday].to_i).to eq(0)
      expect(result['banana'][:thursday].to_i).to eq(24)
      expect(result['banana'][:friday].to_i).to eq(0)
      expect(result['banana'][:saturday].to_i).to eq(24)
      expect(result['banana'][:weekday].to_i).to eq(48)
      expect(result['banana'][:weekend].to_i).to eq(24)
    end

    it 'Should count days correctly (Another Time Zone)' do
      start = ScheduleMaker::Util.dateparse('2016-02-29T00:00:00')
      testobj = ScheduleMaker::DataModel::Weekdays.new
      rotation = ScheduleMaker::Rotation.new(@rotations['simple_1'], count: 3, start: start)
      rotation.override_participant_timezone_from_a_spec_test_only('apple', 'America/Chicago')
      rotation.override_participant_timezone_from_a_spec_test_only('banana', 'Australia/Melbourne')
      result = testobj.pain(rotation, force_calc: true)
      expect(result['apple'][:sunday].to_i).to eq(6)
      expect(result['apple'][:monday].to_i).to eq(18)
      expect(result['apple'][:tuesday].to_i).to eq(6)
      expect(result['apple'][:wednesday].to_i).to eq(18)
      expect(result['apple'][:thursday].to_i).to eq(6)
      expect(result['apple'][:friday].to_i).to eq(18)
      expect(result['apple'][:saturday].to_i).to eq(0)
      expect(result['apple'][:weekday].to_i).to eq(66)
      expect(result['apple'][:weekend].to_i).to eq(6)
      expect(result['banana'][:sunday].to_i).to eq(11)
      expect(result['banana'][:monday].to_i).to eq(0)
      expect(result['banana'][:tuesday].to_i).to eq(13)
      expect(result['banana'][:wednesday].to_i).to eq(11)
      expect(result['banana'][:thursday].to_i).to eq(13)
      expect(result['banana'][:friday].to_i).to eq(11)
      expect(result['banana'][:saturday].to_i).to eq(13)
      expect(result['banana'][:weekday].to_i).to eq(48)
      expect(result['banana'][:weekend].to_i).to eq(24)
    end

    it 'Should count days correctly when adjusting for DST' do
      start = ScheduleMaker::Util.dateparse('2016-03-10T00:00:00')
      testobj = ScheduleMaker::DataModel::Weekdays.new
      rotation = ScheduleMaker::Rotation.new(@rotations['simple_1'], count: 3, start: start)
      # USA DST switches over on 2016-03-13; Australia DST does not switch until 2016-04-03.
      rotation.override_participant_timezone_from_a_spec_test_only('apple', 'America/Chicago')
      rotation.override_participant_timezone_from_a_spec_test_only('banana', 'Australia/Melbourne')
      result = testobj.pain(rotation, force_calc: true)
      expect(result['apple'][:sunday].to_i).to eq(5)
      expect(result['apple'][:monday].to_i).to eq(19)
      expect(result['apple'][:tuesday].to_i).to eq(0)
      expect(result['apple'][:wednesday].to_i).to eq(6)
      expect(result['apple'][:thursday].to_i).to eq(18)
      expect(result['apple'][:friday].to_i).to eq(6)
      expect(result['apple'][:saturday].to_i).to eq(18)
      expect(result['apple'][:weekday].to_i).to eq(49)
      expect(result['apple'][:weekend].to_i).to eq(23)
      expect(result['banana'][:sunday].to_i).to eq(13)
      expect(result['banana'][:monday].to_i).to eq(11)
      expect(result['banana'][:tuesday].to_i).to eq(13)
      expect(result['banana'][:wednesday].to_i).to eq(11)
      expect(result['banana'][:thursday].to_i).to eq(0)
      expect(result['banana'][:friday].to_i).to eq(13)
      expect(result['banana'][:saturday].to_i).to eq(11)
      expect(result['banana'][:weekday].to_i).to eq(48)
      expect(result['banana'][:weekend].to_i).to eq(24)
    end
  end

  describe '#valid?' do
    it 'Should return true if ruleset is empty' do
      testobj = ScheduleMaker::DataModel::Weekdays.new({})
      rotation = ScheduleMaker::Rotation.new(@rotations['simple_1'], count: 2, start: @start)
      expect(testobj.valid?(rotation)).to be true
    end

    it 'Should enforce :max_percent in absence of :max_percent_cutoff' do
      ruleset = { weekend: { penalty: 10, max_percent: 0.4 } }
      testobj = ScheduleMaker::DataModel::Weekdays.new(ruleset)
      rotation = ScheduleMaker::Rotation.new(@rotations['simple_1'], count: 2, start: @start)
      result = testobj.valid?(rotation)
      expect(result).to be false
    end

    it 'Should enforce :max_percent when shifts are above :max_percent_cutoff' do
      ruleset = { weekend: { penalty: 10, max_percent: 0.4, max_percent_cutoff: 1 } }
      testobj = ScheduleMaker::DataModel::Weekdays.new(ruleset)
      rotation = ScheduleMaker::Rotation.new(@rotations['simple_1'], count: 2, start: @start)
      result = testobj.valid?(rotation)
      expect(result).to be false
    end

    it 'Should not enforce :max_percent when shifts are below :max_percent_cutoff' do
      ruleset = { weekend: { penalty: 10, max_percent: 0.4, max_percent_cutoff: 4 } }
      testobj = ScheduleMaker::DataModel::Weekdays.new(ruleset)
      rotation = ScheduleMaker::Rotation.new(@rotations['simple_1'], count: 2, start: @start)
      result = testobj.valid?(rotation)
      expect(result).to be true
    end

    it 'Should not fail if the percentage is below :max_percent' do
      ruleset = { weekend: { penalty: 10, max_percent: 0.7 } }
      testobj = ScheduleMaker::DataModel::Weekdays.new(ruleset)
      rotation = ScheduleMaker::Rotation.new(@rotations['simple_1'], count: 2, start: @start)
      result = testobj.valid?(rotation)
      expect(result).to be true
    end

    it 'Should OR the rules not AND them' do
      ruleset = { weekend: { max_percent: -1 }, weekday: { max_percent: 2 } }
      testobj = ScheduleMaker::DataModel::Weekdays.new(ruleset)
      rotation = ScheduleMaker::Rotation.new(@rotations['simple_1'], count: 2, start: @start)
      result = testobj.valid?(rotation)
      expect(result).to be false
    end

    it 'Should OR the rules not AND them (#2)' do
      ruleset = { weekend: { max_percent: 2 }, weekday: { max_percent: 2 } }
      testobj = ScheduleMaker::DataModel::Weekdays.new(ruleset)
      rotation = ScheduleMaker::Rotation.new(@rotations['simple_1'], count: 2, start: @start)
      result = testobj.valid?(rotation)
      expect(result).to be true
    end

    it 'Should OR the rules not AND them (#3)' do
      ruleset = { weekend: { max_percent: -1 }, weekday: { max_percent: -1 } }
      testobj = ScheduleMaker::DataModel::Weekdays.new(ruleset)
      rotation = ScheduleMaker::Rotation.new(@rotations['simple_1'], count: 2, start: @start)
      result = testobj.valid?(rotation)
      expect(result).to be false
    end
  end
end
