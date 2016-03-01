# Copyright (c) 2016 Kevin Paulisse
#
# schedule_maker is freely distributable under the terms of Apache 2.0 license.
# http://www.apache.org/licenses/LICENSE-2.0
#
# Find the source code, report issues, and contribute at:
# https://github.com/kpaulisse/schedule_maker

module ScheduleMaker
  class Schedule
    attr_reader :rotation

    # Constructor
    # @param hash_of_names [Hash<String,Fixnum>] Participant name and shift length
    def initialize(hash_of_names, options = {})
      # Validate hash of names
      validate_hash_of_names(hash_of_names)

      # Calculate desired rotation period spacing and total length
      count = options.fetch(:rotation_count, 1)
      prev_rotation = options.fetch(:prev_rotation, [])
      @rotation = ScheduleMaker::Rotation.new(hash_of_names, count, prev_rotation)
      @participants = hash_of_names

      # Other variables
      @debug = options.fetch(:debug, false)
    end

    # Callable method to build schedule
    # @param start_date [String] Start date for schedule yyyy-mm-ddThh:mm:ss
    # @param options
    #    (see #to_schedule)
    # @return [Array<Hash<:start,:end,:assignee,:length>>] Resulting schedule in order
    def as_schedule(start_date, options = {})
      ScheduleMaker::ScheduleUtil::to_schedule(start_date, @rotation.schedule, options)
    end

    # Controller to run optimization and detect when an acceptable rotation is built.
    # @param max_iterations [Fixnum] Maximum iterations before giving up
    # @return [ScheduleMaker::Rotation] Optimized rotation
    def optimize(max_iterations = 1000 * (@rotation.rotation_length**2))
      current_state = @rotation.dup
      current_pain = current_state.painscore
      best_state = @rotation.dup
      best_pain = current_pain
      orig_state = @rotation.dup
      orig_pain = current_pain
      current_time = 0
      total_time = 0
      reset_time = 0
      reset_tries = 0
      candidates = []
      candidates << best_state

      while total_time < max_iterations && current_pain > 0
        current_time += 1
        total_time += 1
        reset_time += 1

        new_state = current_state.iterate
        new_pain = new_state.painscore(true)

        if new_pain < best_pain
          best_state = new_state.dup
          best_pain = new_pain
          reset_tries = 0
          reset_time = 0
        end

        if @debug
          str = "Time: #{total_time}<#{max_iterations}"
          str += "|#{reset_time}<#{@participants.keys.size**3}"
          str += "|#{reset_tries}<#{@participants.keys.size**2}"
          str += "; Pain=#{current_pain}|#{new_pain}|#{orig_pain}|#{best_pain}"
          puts str
        end

        if new_pain <= current_pain
          reset_time = 0 if new_pain < current_pain
          next if new_pain == current_pain && rand > 0.25
          current_state = new_state
          current_pain = new_pain
        end

        next unless reset_time >= @participants.keys.size**3
        reset_tries += 1
        break if reset_tries >= @participants.keys.size**2
        current_state = orig_state.dup
        current_pain = current_state.painscore(true)
        current_time = 0
        reset_time = 0
      end

      @rotation = best_state
      best_state
    end

    private

    # Validates hash of names
    # @param hash_of_names [Hash?] Input hash of names
    def validate_hash_of_names(hash_of_names)
      raise ArgumentError, 'ScheduleMaker::Schedule constructor expects a hash for rotation' unless hash_of_names.is_a?(Hash)
      raise ArgumentError, 'Participant list is empty' if hash_of_names.empty?
      raise ArgumentError, 'Participant list must have at least 2 members' if hash_of_names.size < 2
      hash_of_names.keys.each do |key|
        validate_period(key, hash_of_names[key])
      end
    end

    # Validates that a period (participant, shift length) are the right data types and acceptable values.
    # @param key [String] Participant name
    # @param value [Fixnum] Shift length
    # @return [Boolean] True
    def validate_period(key, value)
      raise ArgumentError, "Key #{key.inspect} is a #{key.class}" unless key.is_a?(String)
      raise ArgumentError, 'Empty participant name is not allowed' if key.empty?
      raise ArgumentError, "Key #{key} has invalid period length #{value.class}" unless value.is_a?(Fixnum)
      raise ArgumentError, "period length #{value} is not >= 1" if value < 1
      raise ArgumentError, "period length #{value} is not <= 31" if value > 31
      true
    end
  end
end