# Copyright (c) 2016 Kevin Paulisse
#
# schedule_maker is freely distributable under the terms of Apache 2.0 license.
# http://www.apache.org/licenses/LICENSE-2.0
#
# Find the source code, report issues, and contribute at:
# https://github.com/kpaulisse/schedule_maker

module ScheduleMaker
  module DataModel
    # A ScheduleMaker::DataModel::Spacing allows calculation of "pain" in a rotation arising because
    # shifts for particular participants are not evenly distributed.
    class Spacing
      # Constructor
      # @param options [Hash] Global options
      def initialize(options = {})
        @global_options = options
        @options = @global_options.clone
        @pain_override = nil
        apply_ruleset
      end

      # Calculate the pain array
      # @param rotation [ScheduleMaker::Rotation] Rotation object
      # @param options [Hash] Options to override global options
      # @result [Hash<Participant,Fixnum>] Pain score for each participant
      def pain(rotation, options_in = {})
        return @pain_override unless @pain_override.nil?
        @options = @global_options.merge(options_in)
        result = {}
        @target_spacing = rotation.target_spacing
        @prev_rotation = rotation.prev_rotation
        prev = Hash[@prev_rotation.map { |k, v| [k, 1 - v] }]
        counter = 0
        rotation.rotation.each do |period|
          result[period.participant] ||= { spacing: [], score: 0, pain: false }
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

      # Default rule set
      def default_ruleset
        {
          max: 2,
          threshold: {
            1 => {
              weight: 0,
              max_percent: 1.00,
              max_percent_cutoff: 5
            },
            2 => {
              max_count: 2
            }
          }
        }
      end

      # Create rule set
      def apply_ruleset(options = default_ruleset)
        @ruleset = {}

        # Maximum cumulative score
        if options.key?(:max)
          @ruleset.delete[:max] if options[:max].nil?
          @ruleset[:max] = options[:max] unless options[:max].nil?
        end

        # Thresholds and weights
        @ruleset[:threshold] ||= {}
        if options.key?(:threshold)
          options[:threshold].each do |threskey, thresval|
            if thresval.nil?
              @ruleset[:threshold].delete(threskey)
            else
              @ruleset[:threshold][threskey] = thresval
            end
          end
        end
      end

      # Validate rotation
      def valid?(rotation, options = nil)
        apply_ruleset unless @ruleset.key?(:threshold)
        apply_ruleset(options) unless options.nil?
        threshold_max = @ruleset[:threshold].keys.max
        violations = []
        x_pain = pain(rotation).dup
        x_pain.each do |participant, val|
          next unless val.key?(:spacing)
          next if val[:spacing].empty?

          # Each spacing is a number representing the distance between the target spacing
          # and the actual spacing. The number of "stars" was used in the reporting to indicate
          # how badly this spacing missed the target, with more stars = more pain. Calculate the
          # number of "stars" for each spacing.
          period_length = rotation.participants[participant][:period_length]
          val[:stars] = val[:spacing].map { |k| k > 0 ? ((1.0 * k)/(1.0 * Math.sqrt(period_length))).ceil : 0 }

          # For each item in the threshold, calculate the % of spacings that have that many stars.
          counts = Hash.new(0)
          val[:stars].each { |k| counts[k] += 1 if k > 0 }

          # Assign a cumulative pain score for each point in the threshold, and also check whether
          # the rotation should be immediately invalidated because a particular score exceeds a
          # maximum threshold.
          score = 0
          counts.each do |countkey_, countval|
            countkey = countkey_.to_i

            # Score is worse than any of the keys in the threshold
            if countkey > threshold_max
              violations << {
                participant: participant,
                error: "Spacing=#{countkey} Out of Bounds: #{val[:stars].inspect}"
              }
              next
            end

            # Compare to keys in threshold
            next unless @ruleset[:threshold].key?(countkey)
            threshold = @ruleset[:threshold][countkey]

            # Does absolute count exceed the maximum?
            if threshold.key?(:max_count) && countval >= threshold[:max_count]
              violations << {
                participant: participant,
                error: "Spacing=#{countkey} Threshold: #{countval} >= #{threshold[:max_count]}) #{val[:stars].inspect}"
              }
              next
            end

            # Does percentage of shifts exceed the maximum percentage?
            perc_of_shifts = (1.0 * countval) / (1.0 * val[:spacing].size)
            if threshold.key?(:max_percent) && perc_of_shifts >= threshold[:max_percent]
              unless threshold.key?(:max_percent_cutoff) && countval < threshold[:max_percent_cutoff]
                violations << {
                  participant: participant,
                  error: "Spacing=#{countkey} Percent: #{perc_of_shifts} >= #{threshold[:max_percent]} #{val[:stars].inspect}"
                }
              end
            end
            next unless threshold.key?(:weight)
            score += (1.0 * threshold[:weight] * countval)
          end

          # Cumulative score
          if @ruleset.key?(:max) && score >= @ruleset[:max]
            violations << {
              participant: participant,
              error: "Overall Score=#{score} >= Threshold=#{@ruleset[:max]} #{val[:stars].inspect}"
            }
          end
        end
        rotation.set_violations(self.class.to_s, violations)
        violations.empty?
      end
    end
  end
end
