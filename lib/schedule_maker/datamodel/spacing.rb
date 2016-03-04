# Copyright (c) 2016 Kevin Paulisse
#
# schedule_maker is freely distributable under the terms of Apache 2.0 license.
# http://www.apache.org/licenses/LICENSE-2.0
#
# Find the source code, report issues, and contribute at:
# https://github.com/kpaulisse/schedule_maker

module ScheduleMaker::DataModel
  class Spacing
    # Constructor
    # @param options [Hash] Global options
    def initialize(options = {})
      @global_options = options
      @pain_override = nil
    end

    # Calculate the pain array
    # @param rotation [ScheduleMaker::Rotation] Rotation object
    # @param options [Hash] Options to override global options
    # @result [Hash<Participant,Fixnum>] Pain score for each participant
    def pain(rotation, options_in = {})
      return @pain_override unless @pain_override.nil?
      options = @global_options.merge(options_in)
      result = {}
      @target_spacing = rotation.target_spacing
      @prev_rotation = rotation.prev_rotation
      prev = Hash[@prev_rotation.map {|k,v| [k, 1-v]}]
      counter = 0
      rotation.rotation.each do |period|
        result[period.participant] ||= { :spacing => [], :score => 0, :pain => false }
        score = calculate_pain_score(prev, period, counter)
        add_pain(result, period, score) unless score.nil?

        # Severe penalty for being on the schedule before the start date
        if (rotation.start + (counter * rotation.day_length)) < rotation.participants[period.participant][:start]
          result[period.participant][:pain] = true
          day_diff = (rotation.participants[period.participant][:start] - (rotation.start + counter * rotation.day_length)).to_i
          result[period.participant][:score] += Math.exp([[day_diff, 5].min, 10].max)
        end

        counter += period.period_length
        prev[period.participant] = counter
      end
      result
    end

    # Override pain array - FOR USE IN SPEC TESTING ONLY
    def override_pain_from_a_spec_test_only(pain)
      @pain_override = pain
    end

    # Get pain score
    # Score is the distance between this shift and the previous shift, as compared to the target distance.
    # The target distance is the target spacing times the period length.
    # Example: there's 4 people in the rotation each with 2 day shifts. The target spacing is 6 days off
    # between shifts (because 3 other people each have 2 day shifts, and 3*2=6).
    # @param prev [Hash<Participant, Fixnum>] Previous sightings of participants
    # @param period [ScheduleMaker::Period] Period/shift object
    # @param counter [Fixnum] Position counter
    # @return [Fixnum] Pain score
    def calculate_pain_score(prev, period, counter)
      return 0 unless prev.key?(period.participant)
      score = (@target_spacing * period.period_length) - (counter - prev[period.participant])
      score > 0 ? score : 0
    end

    # Add calculated pain to pain tracker
    # @param period [ScheduleMaker::Period] Period/shift object
    # @param score [Float] Pain score
    def add_pain(result, period, score)
      sqrt_period_length = Math.sqrt(period.period_length)
      result[period.participant][:spacing] << (1.0 * score) / sqrt_period_length
      result[period.participant][:score] += Math.exp(1.0 * score / sqrt_period_length) if score > 0

      # If the difference from the target is N or more days away from the target, where N equals
      # the shift length, this is painful for the person. Set pain=true which will cause future optimization
      # to continue working.
      if (1.0 * score) / sqrt_period_length >= 1.0
        result[period.participant][:pain] = true if (1.0 * score) / sqrt_period_length >= 1.0 || @target_spacing <= 2
      end
    end

    # Validate rotation
    def is_valid?(rotation, options = nil)
      options = { :threshold => { 1 => 1, 2 => 100 }, :max => 2 } if options.nil?
      fail 'Options did not specify :threshold' unless options.key?(:threshold)
      result = true
      x_pain = pain(rotation)
      x_pain.each do |participant, val|
        next unless val.key?(:spacing)
        next if val[:spacing].empty?
        score = 0
        val[:spacing].each do |spacing|
          next if spacing < 1.0
          options[:threshold].each do |thres_key, thres_val|
            score += thres_val if (spacing / Math.sqrt(rotation.participants[participant][:period_length])) > thres_key
            if score >= options[:max]
              result = false
              break
            end
          end
        end
      end
      result
    end
  end
end
