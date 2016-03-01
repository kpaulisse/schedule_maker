# Copyright (c) 2016 Kevin Paulisse
#
# schedule_maker is freely distributable under the terms of Apache 2.0 license.
# http://www.apache.org/licenses/LICENSE-2.0
#
# Find the source code, report issues, and contribute at:
# https://github.com/kpaulisse/schedule_maker

module ScheduleMaker
  # Create a rotation and schedule based on shifts
  class Rotation
    attr_reader :schedule, :participants, :rotation_length, :period_lcm

    # Constructor
    #
    # @param participants [Hash<String,Fixnum>] Participant name (key) and shift length (value)
    # @param count [Fixnum] Number of consecutive schedules to generate
    # @param prev_rotation [Array<Period>] Previous rotation to use in scoring
    # @param initial_schedule [Array<Period>] Starting point
    def initialize(participants, count = 1, prev_rotation = [], initial_schedule = nil)
      raise ArgumentError, 'Participants argument must be a hash' unless participants.is_a?(Hash)
      raise ArgumentError, 'Participants hash cannot be empty' if participants.empty?

      @participants = participants
      @period_lcm = @participants.values.reduce(:lcm)
      @rotation_length = @period_lcm * @participants.keys.size
      @target_spacing = @participants.keys.size - 1
      @schedule = initial_schedule_handler(initial_schedule, count)
      @prev_rotation = build_prev_rotation_hash(prev_rotation)
      @prev_rotation_save = prev_rotation
    end

    def inspect
      "<ScheduleMaker::Rotation schedule=#{@schedule.inspect}, pain=#{pain}, painscore=#{painscore} >"
    end

    def dup
      ScheduleMaker::Rotation.new(@participants, nil, @prev_rotation_save, @schedule.dup)
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
        user_index = @schedule.each_index.select { |i| @schedule[i].participant == user_to_swap }
        index_1 = user_index.sample
        begin_swap = [0, index_1 - Random.rand(@participants.keys.size)].max
        end_swap = [@schedule.size - 1, index_1 + Random.rand(@participants.keys.size)].min
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

      # If nobody is in pain, report 0 as the overall score. Otherwise report the sum.
      is_pain ? result.to_i : 0
    end

    # Force re-calculation of the pain hash for this object
    def recalculate_pain
      calculate_pain
    end

    # Swap two elements in the schedule array
    def swap(index_1, index_2)
      @schedule[index_1], @schedule[index_2] = @schedule[index_2], @schedule[index_1]
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
      return old_score if index_1 == index_2
      return old_score if trial.schedule[index_1].participant == trial.schedule[index_2].participant
      trial.swap(index_1, index_2)
      new_score = trial.painscore(true)
      return new_score if new_score < old_score && rand < 0.90
      trial.swap(index_1, index_2)
      old_score
    end

    # Handle the parameter of the initial schedule, and if it's nil, build the initial schedule.
    def initial_schedule_handler(initial_schedule, count)
      return initial_schedule unless initial_schedule.nil?
      initial_schedule = build_initial_schedule
      result = []
      count.times do
        result.concat initial_schedule
      end
      result
    end

    # Given a previous rotation, build the previous shift for each participant
    # as a hash of <Participant, Previous Shift Offset>
    #
    # @param prev_rotation [Array<Period>] Previous rotation
    # @return [Hash<Participant, Fixnum>] Previous shift offset for each participant
    def build_prev_rotation_hash(prev_rotation)
      result = {}
      counter = 0
      prev_rotation.reverse_each do |period|
        counter += 1
        result[period.participant] ||= counter
        counter += (period.period_length - 1)
      end
      result
    end

    # Turns a hash of <Participant, Period Length> into a hash organized by period length.
    # @return [Hash<Period Length,Array<Participant>>] Participants by period length
    def build_initial_participant_arrays
      participants_by_period = {}
      period_lengths = @participants.values.uniq.sort
      period_lengths.each do |period_length|
        participants = @participants.keys.select { |x| @participants[x] == period_length }.sort
        participants_by_period[period_length] ||= []
        (@period_lcm / period_length).times do
          participants_by_period[period_length].concat participants
        end
      end
      participants_by_period
    end

    # Builds the initial (non-optimized) schedule by evenly distributing the various shift
    # lengths throughout the schedule.
    # @return [Array<Period>] The initial schedule
    def build_initial_schedule
      participants_by_period = build_initial_participant_arrays
      period_lengths = @participants.values.uniq.sort
      shortest_period = period_lengths.shift
      result = participants_by_period[shortest_period].map { |x| ScheduleMaker::Period.new(x, shortest_period) }
      period_lengths.each do |period_length|
        result = insert_into_schedule(result, participants_by_period[period_length], period_length)
      end
      result
    end

    # Drop in new elements to an array at evenly spaced intervals
    #
    #
    def insert_into_schedule(result, participants, period_length)
      spacing = result.size / (1 + participants.size)
      counter = 0
      participants.each do |participant|
        counter += 1
        period = ScheduleMaker::Period.new(participant, period_length)
        result.insert(counter + counter * spacing - 1, period)
      end
      result
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
        @pain[period.participant][:pain] = true if (1.0 * score) / period.period_length > 1.0 || @target_spacing <= 2
      end
      @pain[period.participant][:score] += Math.exp(1.0 * score / period.period_length) if score > 0.0
    end

    # Calculate the pain hash by user
    def calculate_pain
      counter = 0
      prev = {}
      @pain = {}
      @schedule.each do |period|
        initialize_pain(period)
        score = calculate_pain_score(prev, period, counter)
        add_pain(period, score) unless score.nil?
        counter += period.period_length
        prev[period.participant] = counter
      end
    end
  end
end
