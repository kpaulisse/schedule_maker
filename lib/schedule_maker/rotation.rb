# Copyright (c) 2016 Kevin Paulisse
#
# schedule_maker is freely distributable under the terms of Apache 2.0 license.
# http://www.apache.org/licenses/LICENSE-2.0
#
# Find the source code, report issues, and contribute at:
# https://github.com/kpaulisse/schedule_maker

module ScheduleMaker
  # A ScheduleMaker::Rotation object is essentially an Array<Period> that represents the
  # current shift rotation (stored in @rotation) and parameters associated with that rotation.
  # Calculated properties include the "pain" (stored in @pain) which is the metric that is
  # used to compare the desirability of one rotation to another.
  #
  # It has the following important properties:
  # - @rotation        Array<Period>
  # - @count           Fixnum        The number of loops through the participant lists (>= 1)
  # - @start           Timedate      The time/date at which this schedule begins
  # - @day_length      Float         The length (in days) of a shift; defaults to 1.0
  # - @rotation_length Fixnum        The length (in SHIFTS) of the rotation
  # - @rotation_lcm    Fixnum        The least common multiple of all shift lengths
  # - @participants    Hash          Keys are participant names; value is a hash with properties
  # - @prev_rotation   Hash          Tracking when people last had a shift in a prior rotation
  class Rotation
    attr_reader :period_lcm, :rotation_length, :rotation

    # Constructor
    #
    # @param participants [Hash<String,Fixnum>] Participant name (key) and shift length (value)
    # @param count [Fixnum] Number of consecutive schedules to generate
    # @param prev_rotation [Array<Period>] Previous rotation to use in scoring
    # @param init_sched [Array<Period>] Starting point
    # @param options
    #   - :start      => DateTime object representing start date of this period
    #   - :day_length => Float representing the length of a "day" (1.0 is normal)
    def initialize(participants, count = 1, prev_rotation = [], init_sched = nil, options = {})
      raise ArgumentError, 'Participants argument must be a hash' unless participants.is_a?(Hash)
      raise ArgumentError, 'Participants hash cannot be empty' if participants.empty?
      raise ArgumentError, 'Count must be an integer' unless count.is_a?(Fixnum)
      raise ArgumentError, 'Count must be >= 1' unless count >= 1
      @count = count
      @start = options.fetch(:start, ScheduleMaker::Util.midnight_today)
      @day_length = options.fetch(:day_length, 1.0)
      @participants = ScheduleMaker::RotationUtil.prepare_participants(participants, @start)
      @period_lcm = ScheduleMaker::RotationUtil.participant_lcm(participants)
      @target_spacing = @participants.keys.size - 1
      @rotation = ScheduleMaker::RotationUtil.initial_schedule_handler(init_sched, @participants, count, @start, @day_length)
      @rotation_length = ScheduleMaker::RotationUtil.calculate_rotation_length(@rotation)
      @prev_rotation = ScheduleMaker::RotationUtil.build_prev_rotation_hash(prev_rotation)
      @prev_rotation_save = prev_rotation
    end

    def inspect
      "<ScheduleMaker::Rotation schedule=#{@rotation.inspect}, pain=#{pain}, painscore=#{painscore} >"
    end

    def dup
      options = {
        start: @start,
        day_length: @day_length
      }
      ScheduleMaker::Rotation.new(@participants, @count, @prev_rotation_save, @rotation.dup, options)
    end

    # Causes one iteration upon the rotation. An iteration is ordering the users by their current pain
    # score and selecting (randomly) a participant, weighted to select one whose pain is high. Then a
    # trial is done by selecting 1-4 of this user's shifts and swapping those shifts with someone else's.
    # For each swap the pain score is re-calculated. If the new overall pain is less than the present,
    # the swap is permanent (except, 10% of the time, randomly, it's not). The randomness here is used
    # to provide paths to a global minimum, without always following the same path which may only take
    # it to a local minimum.
    # @return [ScheduleMaker::Rotation] The iterated object
    def iterate
      calculate_pain if @pain.nil? || @pain.empty?
      users_in_pain = @pain.keys.sort_by { |k| -@pain[k][:score] }
      trial = dup
      1.upto(1 + Random.rand(3)) do
        user_to_swap = ScheduleMaker::Util.randomelement(users_in_pain)
        user_index = @rotation.each_index.select { |i| @rotation[i].participant == user_to_swap }
        index_1 = user_index.sample
        begin_swap = [0, index_1 - Random.rand(@participants.keys.size)].max
        end_swap = [@rotation.size - 1, index_1 + Random.rand(@participants.keys.size)].min
        old_score = trial.painscore(true)
        begin_swap.upto(end_swap) do |index_2|
          old_score = iterate_try_swap(trial, index_1, index_2, old_score)
        end
      end
      trial.recalculate_pain
      trial
    end

    def pain
      calculate_pain if @pain.nil?
      @pain
    end

    # Return the overall "pain score" for a schedule, which is the metric used to determine
    # if one schedule is superior to another.
    # @param force_calc [Boolean] Set to true to force a re-calculation
    # @param pain [Hash<Participant,Pain>] Override object's pain array for this calculation
    # @return [Fixnum] Pain score of schedule
    def painscore(force_calc = false, pain = nil)
      result = 0.0
      is_pain = false
      if pain.nil?
        calculate_pain if @pain.nil? || force_calc
        pain = @pain
      end

      # This uses a sum of squares, so that significant pain for any participant will
      # bump up the overall score more than a little pain for everyone. The choice to
      # use squares here instead of anything else was arbitrary but seemed to work well
      # with the test cases I used.
      pain.keys.each do |participant|
        is_pain = true if pain[participant][:pain]
        result += pain[participant][:score]**2
      end

      # Low total pain determined based on participant count amount
      return 0 if result < (@participants.keys.size * @count * Math.exp(1)) && equitable?

      # If nobody is in pain, report 0 as the overall score. Otherwise report the sum.
      is_pain ? result.to_i : 0
    end

    # Check for inequitable schedule
    def equitable?(pain = @pain)
      max_seen = 0.0
      min_seen = 1.0 * @rotation_length
      pain.values.each do |ele|
        adjusted_spacing = ele[:spacing].select { |x| x >= 0 }
        min_spacing = adjusted_spacing.min || 0
        max_spacing = adjusted_spacing.max || max_seen
        min_seen = 1.0 * min_spacing if min_spacing < min_seen
        max_seen = 1.0 * max_spacing if max_spacing > max_seen
      end
      (min_seen - max_seen).abs <= 1.0
    end

    # Force re-calculation of the pain hash for this object
    def recalculate_pain
      calculate_pain
    end

    # Swap two elements in the schedule array
    def swap(index_1, index_2)
      @rotation[index_1], @rotation[index_2] = @rotation[index_2], @rotation[index_1]
    end

    # Is a proposed swap legal?
    def swap_legal?(index_1, index_2)
      # Shortcuts
      return false if index_1 == index_2
      return false if @rotation[index_1].participant == @rotation[index_2].participant

      # Check whether the person in the currently later shift has a start time restriction
      max_index = [index_1, index_2].max
      max_participant = @rotation[max_index].participant
      return true if @participants[max_participant][:start] <= @start

      # Calculate the end date of the shift that we propose to move the later person to.
      # If this date is before the start date, then this swap is illegal.
      min_index = [index_1, index_2].min
      shift_counter = 0
      0.upto(min_index - 1) do |i|
        shift_counter += @rotation[i].period_length
      end
      start_of_shift = @start + (shift_counter * @day_length)
      @participants[max_participant][:start] <= start_of_shift
    end

    # Override a participant's start date - FOR USE IN SPEC TESTING ONLY
    def override_participant_start_date_from_a_spec_test_only(key, start_date)
      raise "Participant '#{key}' is not defined here" unless @participants.key?(key)
      @participants[key][:start] = ScheduleMaker::Util.dateparse(start_date)
    end

    private

    # Perform a trial swap of index_1 and index_2. If an improvement to score was made, then 90%
    # of the time leave the swap in place. If the score didn't improve, or 10% of randomness hit,
    # undo the swap.
    # @param trial [ScheduleMaker::Rotation] Rotation being adjusted / evaluated
    # @param index_1 [Fixnum] Index of first shift to swap
    # @param index_2 [Fixnum] Index of second shift to swap
    # @return [Fixnum] Pain score for current state of trial rotation
    def iterate_try_swap(trial, index_1, index_2, old_score)
      return old_score unless swap_legal?(index_1, index_2)
      trial.swap(index_1, index_2)
      new_score = trial.painscore(true)
      return new_score if new_score < old_score && rand < 0.90
      trial.swap(index_1, index_2)
      old_score
    end

    # Initialize pain object for a participant
    # @param period [ScheduleMaker::Period] Period/shift object
    def initialize_pain(period)
      @pain[period.participant] ||= {}
      @pain[period.participant][:spacing] ||= []
      @pain[period.participant][:score] ||= 0
      @pain[period.participant][:pain] ||= false
      @pain[period.participant][:period_length] ||= period.period_length
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
      return (@target_spacing * period.period_length) - (counter - prev[period.participant]) if prev.key?(period.participant)
      return nil unless @pain[period.participant][:spacing].empty? && @prev_rotation.key?(period.participant)
      (@target_spacing * period.period_length) - (counter + @prev_rotation[period.participant])
    end

    # Add calculated pain to pain tracker
    # @param period [ScheduleMaker::Period] Period/shift object
    # @param score [Float] Pain score
    def add_pain(period, score)
      @pain[period.participant][:spacing] << (1.0 * score) / period.period_length

      # If the difference from the target is N or more days away from the target, where N equals
      # the shift length, this is painful for the person. Set pain=true which will cause future optimization
      # to continue working.
      if (1.0 * score) / period.period_length >= 1.0
        @pain[period.participant][:pain] = true if (1.0 * score) / period.period_length >= 1.0 || @target_spacing <= 2
      end
      @pain[period.participant][:score] += Math.exp(1.0 * score / period.period_length) if score > 0.0
    end

    # Calculate the pain hash by user
    def calculate_pain
      counter = 0
      prev = {}
      @pain = {}
      @rotation.each do |period|
        initialize_pain(period)
        score = calculate_pain_score(prev, period, counter)
        add_pain(period, score) unless score.nil?
        if (@start + counter * @day_length) < @participants[period.participant][:start]
          @pain[period.participant][:pain] = true
          day_diff = @participants[period.participant][:start] - (@start + counter * @day_length)
          @pain[period.participant][:score] += Math.exp([[day_diff, 5].min, 10].max)
        end
        counter += period.period_length
        prev[period.participant] = counter
      end
    end
  end
end
