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

    # -----------
    # Constructor
    # -----------
    def initialize(hash_of_names, options = {})
      # Validate hash of names
      fail 'ScheduleMaker::Schedule constructor expects a hash for rotation' unless hash_of_names.is_a?(Hash)
      fail 'Participant list is empty' if hash_of_names.empty?
      fail 'Participant list must have at least 2 members' if hash_of_names.size < 2

      # Validate each entry in hash table
      hash_of_names.keys.each do |key|
        validate_period(key, hash_of_names[key])
      end

      # Calculate desired rotation period spacing and total length
      count = options.fetch(:rotation_count, 1)
      prev_rotation = options.fetch(:prev_rotation, [])
      @rotation = ScheduleMaker::Rotation.new(hash_of_names, count, prev_rotation)
      @participants = hash_of_names

      # Other variables
      @debug = options.fetch(:debug, false)
    end

    def as_schedule(start_date, options = {})
      unless start_date =~ /^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})/
        fail 'Date expects format XXXX-XX-XXTXX:XX:XX'
      end
      require 'date'
      start = DateTime.parse("#{start_date}+00:00")
      shift_length = options.fetch(:shift_length, 1)
      consolidated = options.fetch(:consolidated, false)
      offset = options.fetch(:offset, '+00:00')
      rotation = options.fetch(:rotation, @rotation)
      result = []
      prev = {}
      rotation.schedule.each do |period|
        if consolidated
          hsh = {}
          hsh[:start] = start.strftime('%Y-%m-%dT%H:%M:%S+00:00')
          hsh[:end] = (start + period.period_length*shift_length).strftime('%Y-%m-%dT%H:%M:%S+00:00')
          hsh[:assignee] = period.participant
          hsh[:length] = period.period_length
          if prev.key?(period.participant)
            hsh[:prev] = (start.to_time.to_i - prev[period.participant])/(24.0*60*60)
          end
          prev[period.participant] = start.to_time.to_i
          result << hsh
          start += shift_length * period.period_length
        else
          period.period_length.times do
            hsh = {}
            hsh[:start] = start.strftime("%Y-%m-%dT%H:%M:%S#{offset}")
            hsh[:end] = (start + shift_length).strftime("%Y-%m-%dT%H:%M:%S#{offset}")
            hsh[:assignee] = period.participant
            hsh[:length] = period.period_length
            if prev.key?(period.participant)
              hsh[:prev] = (start.to_time.to_i - prev[period.participant])/(24.0*60*60)
            end
            result << hsh
            start += shift_length
          end
          prev[period.participant] = start.to_time.to_i
        end
      end
      result
    end

    def optimize(max_iterations = 1000 * (@rotation.rotation_length ** 2))
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

      while total_time < max_iterations and current_pain > 0
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
          str += "|#{reset_time}<#{@participants.keys.size ** 3}"
          str += "|#{reset_tries}<#{@participants.keys.size ** 2}"
          str += "; Pain=#{current_pain}|#{new_pain}|#{orig_pain}|#{best_pain}"
          puts str
        end

        if new_pain <= current_pain
          reset_time = 0 if new_pain < current_pain
          next if new_pain == current_pain && rand > 0.25
          current_state = new_state
          current_pain = new_pain
        end

        if reset_time >= (@participants.keys.size ** 3)
          reset_tries += 1
          break if reset_tries >= @participants.keys.size ** 2
          current_state = orig_state.dup
          current_pain = current_state.painscore(true)
          current_time = 0
          reset_time = 0
        end
      end

      @rotation = best_state
      best_state
    end

    private

    def validate_period(key, value)
      fail "Key #{key.inspect} is a #{key.class}" unless key.is_a?(String)
      fail "Key #{key} has invalid period length #{value.class}" unless value.is_a?(Fixnum)
      fail "period length #{value} is not >= 1" if value < 1
      fail "period length #{value} is not <= 31" if value > 31
      true
    end
  end
end
