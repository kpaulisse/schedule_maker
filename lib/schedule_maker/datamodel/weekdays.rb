# Copyright (c) 2016 Kevin Paulisse
#
# schedule_maker is freely distributable under the terms of Apache 2.0 license.
# http://www.apache.org/licenses/LICENSE-2.0
#
# Find the source code, report issues, and contribute at:
# https://github.com/kpaulisse/schedule_maker

module ScheduleMaker::DataModel
  # This class determines "fairness" of a particular schedule by calculating the
  # percentage of the time a person is assigned to a weekend. The result for each
  # participant is a number from 0 (no weekend at all) to 1 (all weekend).
  #
  # Options:
  # - minimum_shift_hours [Fixnum] Don't report on participants covering less than this number of hours
  class Weekdays
    attr_accessor :violations, :date_cache, :hour_cache, :cache

    # Constructor
    # @param options [Hash] Global options
    def initialize(options = {})
      @global_options = options
      @pain_override = nil
      @ruleset = apply_ruleset
      @cache ||= {}
      @date_cache ||= {}
      @hour_cache ||= {}
      @day_to_period = {
        sunday: :weekend,
        monday: :weekday,
        tuesday: :weekday,
        wednesday: :weekday,
        thursday: :weekday,
        friday: :weekday,
        saturday: :weekend
      }
    end

    # Default rule set
    def default_ruleset
      # Leaving this blank in the gem, because in some cases, weekends are good.
      # In other cases, weekends are bad.
      { }
    end

    # Create rule set
    def apply_ruleset(options = default_ruleset)
      @ruleset ||= {}
      options.each do |key, val|
        if val.nil?
          @ruleset.delete(key)
        else
          @ruleset[key] = val
        end
      end
    end

    # Cached dates
    def cached_date(time_in, timezone = 'UTC')
      return @date_cache[time_in][timezone] if @date_cache.key?(time_in) && @date_cache[time_in].key?(timezone)
      @date_cache[time_in] ||= {}
      @date_cache[time_in][timezone] = ScheduleMaker::Util.dateparse(time_in, timezone)
      @date_cache[time_in][timezone]
    end

    # Cached hours
    def cached_hour(key, timezone = 'UTC')
      return @hour_cache[key][timezone] if @hour_cache.key?(key) && @hour_cache[key].key?(timezone)
      @hour_cache[key] ||= {}
      @hour_cache[key][timezone] = [:sunday, :monday, :tuesday, :wednesday, :thursday, :friday, :saturday][key.wday]
      @hour_cache[key][timezone]
    end

    # Need to cache date lookups and stats
    def get_hours(start, endt, timezone = 'UTC', result = nil)
      start_val = start.strftime('%s')
      end_val = endt.strftime('%s')
      if @cache.key?(start_val) && @cache[start_val].key?(end_val) && @cache[start_val][end_val].key?(timezone)
        return @cache[start_val][end_val][timezone]
      end
      result ||= {
        sunday: 0,
        monday: 0,
        tuesday: 0,
        wednesday: 0,
        thursday: 0,
        friday: 0,
        saturday: 0,
        weekend: 0,
        weekday: 0
      }
      @cache[start_val] ||= {}
      @cache[start_val][end_val] ||= {}
      @cache[start_val][end_val][timezone] ||= {}
      start_time = cached_date(start, timezone)
      end_time = cached_date(endt, timezone)
      0.upto((24 * (end_time - start_time).to_f).to_i - 1) do |index|
        key = (start_time + index * (1 / 24.0) + 0.00000001)
        wday = cached_hour(key, timezone)
        result[wday] += 1
        result[@day_to_period[wday]] += 1
      end
      @cache[start_val][end_val][timezone] = result
      result
    end

    # Calculate the pain array
    # @param rotation [ScheduleMaker::Rotation] Rotation object
    # @param options [Hash] Options to override global options
    # @result [Hash<Participant,Fixnum>] Pain score for each participant
    def pain(rotation, options_in = {})
      return @pain_override unless @pain_override.nil?
      options = @global_options.merge(options_in)
      return rotation.participants.map { |k,v| [ k, { score: 0, skipped: true } ] }.to_h if @ruleset.empty?
      result = {}
      timezone_cache = {}
      counter = 0
      rotation.rotation.each do |period|
        result[period.participant] ||= { score: 0, shifts: 0, skipped: false }
        result[period.participant][:shifts] += 1
        timezone = timezone_cache.key?(period.participant) ? timezone_cache[period.participant] :
          rotation.participants[period.participant].key?(:timezone) ? rotation.participants[period.participant][:timezone] : 'UTC'
        start_time = rotation.start + (counter * rotation.day_length * period.period_length)
        end_time = rotation.start + ((1 + counter) * rotation.day_length * period.period_length)
        hours = get_hours(start_time, end_time, timezone)
        hours.each do |k, v|
          result[period.participant][k] ||= 0
          result[period.participant][k] += v
        end
        counter += 1
      end
      result.each do |participant, val|
        total_hours = val[:weekend] + val[:weekday]
        next if total_hours == 0
        @ruleset.each do |sym, symval|
          next unless val.key?(sym) && symval.key?(:penalty)
          perc = (1.0 * val[sym]) / (1.0 * total_hours)
          result[participant][:score] += (Math.exp(1.0 * perc * symval[:penalty]) - 1)
        end
      end
      result
    end

    # Valid?
    def valid?(rotation, options = {})
      return true if @ruleset.empty?
      violations = []
      x_pain = pain(rotation, options)
      x_pain.each do |participant, val|
        total_hours = val[:weekend] + val[:weekday]
        next if total_hours == 0
        @ruleset.each do |sym, symval|
          next unless val.key?(sym)
          perc = (1.0 * val[sym]) / (1.0 * total_hours)
          if symval.key?(:max_percent) && perc >= symval[:max_percent]
            next if symval.key?(:max_percent_cutoff) && val[:shifts] < symval[:max_percent_cutoff]
            violations << {
              participant: participant,
              error: "Week day violation for #{participant}: #{perc} > #{symval[:max_percent]} - #{val.inspect}"
            }
          end
        end
      end
      rotation.set_violations(self.class.to_s, violations)
      violations.empty?
    end

    # Override pain array - FOR USE IN SPEC TESTING ONLY
    def override_pain_from_a_spec_test_only(pain)
      @pain_override = pain
    end
  end
end
