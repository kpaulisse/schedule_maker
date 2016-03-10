# Copyright (c) 2016 Kevin Paulisse
#
# schedule_maker is freely distributable under the terms of Apache 2.0 license.
# http://www.apache.org/licenses/LICENSE-2.0
#
# Find the source code, report issues, and contribute at:
# https://github.com/kpaulisse/schedule_maker

module ScheduleMaker
  module DataModel
    # This class determines "fairness" of a particular schedule by calculating the
    # percentage of the time a person is assigned to a weekend. The result for each
    # participant is a number from 0 (no weekend at all) to 1 (all weekend).
    #
    # Options:
    # - minimum_shift_hours [Fixnum] Don't report on participants covering less than this number of hours
    class Weekdays
      attr_accessor :violations, :wday_cache, :hour_cache, :cache

      # Constructor
      # @param options [Hash] Global options
      def initialize(options = ScheduleMaker::Util.load_ruleset('weekends-are-bad')["#{self.class}::Hash"])
        @pain_override = nil
        @ruleset = apply_ruleset(options)
        @cache ||= {}
        @date_cache ||= {}
        @wday_cache ||= {}
        @hour_cache ||= {}
        @timezone_cache ||= {}
        @day_array = [:sunday, :monday, :tuesday, :wednesday, :thursday, :friday, :saturday]
        @weekend_cache = build_weekend_cache
      end

      # Create rule set
      def apply_ruleset(options)
        @ruleset ||= {}
        options.each do |key, val|
          if val.nil?
            @ruleset.delete(key)
          else
            @ruleset[key] = val
          end
        end
      end

      # Weekend vs. Weekday
      def is_weekend?(day, hour)
        the_day = day.is_a?(Fixnum) ? @day_array[day] : day
        @weekend_cache[the_day][hour]
      end

      def build_weekend_cache
        @ruleset.key?(:weekend_range) ? build_weekend_cache_custom : build_weekend_cache_default
      end

      def build_weekend_cache_default
        result = {}
        @day_array.each do |day|
          result[day] = Array.new(24, day == :saturday || day == :sunday)
        end
        result
      end

      def build_weekend_cache_custom
        result = {}
        @day_array.each do |day|
          result[day] = Array.new(24, false)
        end
        @ruleset[:weekend_range].each do |tuple|
          # Start at 00:00 on a day, end at a specific hour
          if tuple[0].nil? && tuple.size == 2
            tuple_day = tuple[1][:day]
            tuple_hour = tuple[1][:hour]
            0.upto(tuple_hour-1) do |hour|
              result[tuple_day][hour] = true
            end

          # Start at a specific time on a day, go through EOD
          elsif tuple.size == 1
            tuple_day = tuple[0][:day]
            tuple_hour = tuple[0][:hour]
            tuple_hour.upto(23) do |hour|
              result[tuple_day][hour] = true
            end

          # Specific hour range for a day
          else
            tuple_day = tuple[0][:day]
            tuple_hour_start = tuple[0][:hour]
            tuple_hour_end = tuple[1][:hour]
            tuple_hour_start.upto(tuple_hour_end-1) do |hour|
              result[tuple_day][hour] = true
            end
          end
        end
        result
      end

      # Cached hours
      def cached_hour(key, timezone = 'UTC')
        return @hour_cache[key.to_i][timezone] if @hour_cache.key?(key.to_i) && @hour_cache[key.to_i].key?(timezone)
        other_timezone = ScheduleMaker::Util.offset_tz(key, timezone, @timezone_cache)
        @hour_cache[key.to_i] ||= {}
        @hour_cache[key.to_i][timezone] = other_timezone.hour
        @hour_cache[key.to_i][timezone]
      end

      # Cached weekday, by hours
      def cached_wday(key, timezone = 'UTC')
        return @wday_cache[key.to_i][timezone] if @wday_cache.key?(key.to_i) && @wday_cache[key.to_i].key?(timezone)
        other_timezone = ScheduleMaker::Util.offset_tz(key, timezone, @timezone_cache)
        @wday_cache[key.to_i] ||= {}
        @wday_cache[key.to_i][timezone] = @day_array[other_timezone.wday]
        @wday_cache[key.to_i][timezone]
      end

      # Need to cache date lookups and stats
      def get_hours(start, endt, timezone = 'UTC', result = nil)
        start_val = start.to_i
        end_val = endt.to_i
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
        iter = start.dup
        until iter >= endt
          wday = cached_wday(iter, timezone)
          result[wday] += 1
          weekday_weekend = is_weekend?(wday, cached_hour(iter, timezone)) ? :weekend : :weekday
          result[weekday_weekend] += 1
          iter += 3600
        end
        @cache[start_val][end_val][timezone] = result
        result
      end

      # Calculate the pain array
      # @param rotation [ScheduleMaker::Rotation] Rotation object
      # @result [Hash<Participant,Fixnum>] Pain score for each participant
      def pain(rotation, options_in = {})
        return @pain_override unless @pain_override.nil?
        if @ruleset.empty? && !options_in.fetch(:force_calc, false)
          return rotation.participants.map { |k, _v| [k, { score: 0, skipped: true }] }.to_h
        end
        result = {}
        timezone_cache = {}
        iter = rotation.start.clone
        rotation.rotation.each do |period|
          result[period.participant] ||= { score: 0, shifts: 0, skipped: false }
          result[period.participant][:shifts] += 1
          timezone =
            if timezone_cache.key?(period.participant)
              timezone_cache[period.participant]
            elsif rotation.participants[period.participant].key?(:timezone)
              rotation.participants[period.participant][:timezone]
            else
              'UTC'
            end
          hours = get_hours(iter, iter + rotation.day_length * period.period_length, timezone)
          hours.each do |k, v|
            result[period.participant][k] ||= 0
            result[period.participant][k] += v
          end
          iter += rotation.day_length * period.period_length
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
      def valid?(rotation, _options = {})
        return true if @ruleset.empty?
        violations = []
        x_pain = pain(rotation)
        x_pain.each do |participant, val|
          total_hours = val[:weekend] + val[:weekday]
          next if total_hours == 0
          @ruleset.each do |sym, symval|
            next unless val.key?(sym)
            perc = (1.0 * val[sym]) / (1.0 * total_hours)
            next unless symval.key?(:max_percent) && perc >= symval[:max_percent]
            next if symval.key?(:max_percent_cutoff) && val[:shifts] < symval[:max_percent_cutoff]
            violations << {
              participant: participant,
              error: "Week day violation for #{participant}: #{perc} > #{symval[:max_percent]} - #{val.inspect}"
            }
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
end
