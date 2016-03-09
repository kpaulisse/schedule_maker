# Copyright (c) 2016 Kevin Paulisse
#
# schedule_maker is freely distributable under the terms of Apache 2.0 license.
# http://www.apache.org/licenses/LICENSE-2.0
#
# Find the source code, report issues, and contribute at:
# https://github.com/kpaulisse/schedule_maker

module ScheduleMaker
  # Static methods to help construct and otherwise deal with rotations
  class RotationUtil
    # Given a previous rotation, build the previous shift for each participant
    # as a hash of <Participant, Previous Shift Offset>. This is a static method
    # because it's called directly from other classes as well.
    #
    # @param prev_rotation [Array<Period>] Previous rotation
    # @return [Hash<Participant, Fixnum>] Previous shift offset for each participant
    def self.build_prev_rotation_hash(prev_rotation)
      result = {}
      counter = 0
      prev_rotation.reverse_each do |period|
        counter += 1
        result[period.participant] ||= counter
        counter += (period.period_length - 1)
      end
      result
    end

    # Get the LCM of all the shift lengths in a particular participant hash
    # @param participants [Hash<String, (Fixnum|Hash)>] Participant hash
    # @return [Fixnum] LCM of shift lengths
    def self.participant_lcm(participants)
      raise 'participant_lcm(participants) failed on empty input' if participants.empty?
      integer_array = []
      participants.values.each do |val|
        case val
        when Fixnum
          integer_array << val
        when ScheduleMaker::Period
          integer_array << val.period_length
        when Hash
          integer_array << ScheduleMaker::Util.get_element_from_hash(val, :period_length, nil)
        else
          raise "participant_lcm failed on #{val.class} : '#{val.inspect}'"
        end
      end
      integer_array.reduce(:lcm)
    end

    # Prepare participants hash, supporting both integer (shift length) and hash (shift length with other
    # options) as the argument for each participant.
    # @param participants [Hash<String, (Fixnum|Hash)>] Participant hash
    # @return [Hash] Prepared participants
    def self.prepare_participants(participants, start)
      result = {}
      participants.keys.each do |key|
        p_k = participants[key]
        result[key] = {}
        result[key][:period_length] = ScheduleMaker::Util.get_element_from_hash(p_k, :period_length, p_k)
        result[key][:start] = ScheduleMaker::Util.dateparse(ScheduleMaker::Util.get_element_from_hash(p_k, :start, start))
        result[key][:timezone] = ScheduleMaker::Util.get_element_from_hash(p_k, :timezone, 'UTC')
      end
      result
    end

    # Handle the parameter of the initial schedule, and if it's nil, build the initial schedule.
    # This is called by ScheduleMaker::Rotation to create the initial schedule
    def self.initial_schedule_handler(initial_schedule = nil, participants, count, start, day_length)
      return initial_schedule unless initial_schedule.nil?
      build_initial_schedule(participants, count, start, day_length)
    end

    # Builds the initial (non-optimized) schedule by evenly distributing the various shift
    # lengths throughout the schedule.
    # @param participants [Hash] Participants hash
    # @param count [Fixnum] Number of consecutive schedules to create
    # @return [Array<Period>] The initial schedule
    def self.build_initial_schedule(participants, count, start, day_length)
      participants_by_period = build_initial_participant_arrays(participants, count)
      period_lengths = participants.values.map { |x| x[:period_length] }.uniq.sort
      shortest_period = period_lengths.shift
      result = participants_by_period[shortest_period].map { |x| ScheduleMaker::Period.new(x, shortest_period) }
      period_lengths.each do |period_length|
        insert_into_schedule(result, participants_by_period[period_length], period_length)
      end
      remove_from_schedule(result, participants, start, day_length, count)
      result
    end

    # Turns a hash of <Participant, Period Length> into a hash organized by period length.
    # @param participants [Hash] Participants hash
    # @param count [Fixnum] Number of rotations to build
    # @return [Hash<Period Length,Array<Participant>>] Participants by period length
    def self.build_initial_participant_arrays(participants, count)
      participants_by_period = {}
      period_lengths = participants.values.map { |x| x[:period_length] }.uniq.sort
      period_lcm = participant_lcm(participants)
      period_lengths.each do |period_length|
        these_participants = participants.keys.select { |x| participants[x][:period_length] == period_length }.sort
        participants_by_period[period_length] ||= []
        (count * period_lcm / period_length).times do
          participants_by_period[period_length].concat these_participants
        end
      end
      participants_by_period
    end

    # Drop in new elements to an array at evenly spaced intervals
    # @param result [Array<Period>] Array that will be modified by this method
    # @param participants [Hash] Participants hash
    # @param period_length [Fixnum] Length of a shift
    def self.insert_into_schedule(result, participants, period_length)
      spacing = result.size / (1 + participants.size)
      counter = 0
      participants.each do |participant|
        counter += 1
        period = ScheduleMaker::Period.new(participant, period_length)
        result.insert(counter + counter * spacing - 1, period)
      end
    end

    # Remove people from this schedule based on start dates
    # @param result [Array<Period>] Array that will be modified by this method
    # @param participants [Hash] Participants hash
    # @return [Fixnum] Number of elements removed
    def self.remove_from_schedule(result, participants, start, day_length, count = 1)
      period_lengths = participants.values.map { |x| x[:period_length] }.uniq.sort
      period_lcm = period_lengths.reduce(:lcm)
      calculated_shifts = calculate_shifts(participants, period_lcm, start, day_length, count)
      removed_count = 0
      (result.size - 1).downto(0) do |index|
        ele = result[index]
        calculated_shifts[ele.participant] -= 1
        next if calculated_shifts[ele.participant] >= 0
        removed_count += remove_schedule_element(result, index)
      end
      result = result.delete_if(&:nil?)
      removed_count
    end

    # Remove element at index and adjust rotation length accordingly
    # @param result [Array<Period>] Array that will be modified by this method
    # @param index [Fixnum] Index location to remove
    # @return Fixnum number of periods removed
    def self.remove_schedule_element(result, index)
      ele = result[index]
      result[index] = nil
      ele.period_length
    end

    # Calculate the number of shifts that a participant must cover
    # @param participants [Hash] Participants hash
    # @param start [DateTime] Date and time that the rotation starts
    # @param day_length [Float] Length of a single shift in days
    # @rotation_length [Fixnum] Length of the rotation
    def self.calculate_shifts(participants, period_lcm, start, day_length, count = 1)
      schedule_end = start + (count * day_length * participants.keys.size * period_lcm)
      schedule_length = (schedule_end - start).to_i
      result = {}
      participants.keys.each do |key|
        this_start = participants[key][:start]
        expected_shifts = period_lcm * count / participants[key][:period_length]
        if this_start >= schedule_end
          result[key] = 0
        elsif this_start <= start
          result[key] = expected_shifts
        else
          percent_missed = (this_start - start) * 86400.0 / (schedule_length * day_length)
          result[key] = (((1 - percent_missed) * expected_shifts) + 0.5).to_i
        end
      end
      result
    end

    # Calculate rotation length
    # @param rotation [Array<Period>] Rotation
    # @result Fixnum Sum of all period lengths in rotation
    def self.calculate_rotation_length(rotation)
      return 0 unless rotation.is_a?(Array) && !rotation.empty?
      rotation.map(&:period_length).reduce(&:+)
    end
  end
end
