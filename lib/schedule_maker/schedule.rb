# Copyright (c) 2016 Kevin Paulisse
#
# schedule_maker is freely distributable under the terms of Apache 2.0 license.
# http://www.apache.org/licenses/LICENSE-2.0
#
# Find the source code, report issues, and contribute at:
# https://github.com/kpaulisse/schedule_maker

require 'yaml'

module ScheduleMaker
  # A ScheduleMaker::Schedule object is the externally-facing representation of a shift
  # schedule. It contains the rotation (stored in @rotation) which is essentially an Array<Period>
  # and some additional metadata and methods. It also contains the 'optimize' method, which
  # repeatedly calls the 'iterate' method on the underlying rotation, and controls when the result
  # is good enough to exit.
  #
  # It has the following important properties:
  # - @rotation                ScheduleMaker::Rotation  The underlying rotation of shifts
  # - @debug                   Boolean                  Cause debugging information to print
  # - @number_of_participants  Fixnum                   Number of unique participants in rotation
  # - @start                   DateTime                 Start date for schedule and rotation
  class Schedule
    attr_reader :rotation, :start

    # Constructor
    # @param hash_of_names [Hash<String,Fixnum>] Participant name and shift length
    def initialize(hash_of_names, options = {})
      # Validate hash of names
      validate_hash_of_names(hash_of_names)
      @number_of_participants = hash_of_names.keys.size

      # Calculate desired rotation period spacing and total length
      @start = ScheduleMaker::Util.dateparse(options.fetch(:start, ScheduleMaker::Util.midnight_today))

      # Get the rotation
      @rotation = if options.key?(:rotation) && !options[:rotation].nil?
                    options[:rotation]
                  else
                    rotation_options = {
                      count: options.fetch(:rotation_count, 1),
                      prev_rotation: options.fetch(:prev_rotation, []),
                      start: @start
                    }
                    rotation_options[:ruleset] = options[:ruleset] if options.key?(:ruleset)
                    ScheduleMaker::Rotation.new(hash_of_names, rotation_options)
                  end

      # Other variables
      @debug = options.fetch(:debug, false)
    end

    # Callable method to build schedule
    # @param start_date [String] Start date for schedule yyyy-mm-ddThh:mm:ss
    # @param options
    #    (see #to_schedule)
    # @return [Array<Hash<:start,:end,:assignee,:length>>] Resulting schedule in order
    def as_schedule(start_date = @start, options = {})
      ScheduleMaker::ScheduleUtil.to_schedule(start_date, @rotation.rotation, options)
    end

    # Print a debugging string
    def print_debugging_string(options, inputs)
      str = "Time: #{inputs[:total_iter]}<#{options[:max_iterations]}"
      str += "|#{inputs[:reset_counter]}<#{options[:reset_max]}"
      str += "|#{inputs[:reset_tries_counter]}<#{options[:reset_try_max]}"
      str += "; Pain=#{inputs[:current_pain]}|#{inputs[:new_pain]}|#{inputs[:orig_pain]}|#{inputs[:best_pain]}"
      STDERR.puts str
    end

    # Controller to run optimization and detect when an acceptable rotation is built.
    # @param max_iterations [Fixnum] Maximum iterations before giving up
    # @return [ScheduleMaker::Rotation] Optimized rotation
    def optimize(options_in = {})
      options = {
        reset_try_max: 2,
        reset_max: [@number_of_participants, 5].max,
        max_iterations: @rotation.rotation_length**2
      }.merge(options_in)

      current_state = @rotation.dup
      current_pain = current_state.painscore
      best_state = @rotation.dup
      best_pain = current_pain
      orig_state = @rotation.dup
      orig_pain = current_pain
      current_iter = 0
      total_iter = 0
      reset_counter = 0
      reset_tries_counter = 0
      candidates = []
      candidates << best_state

      while total_iter < options[:max_iterations] && current_pain > 0
        current_iter += 1
        total_iter += 1
        reset_counter += 1

        new_state = current_state.iterate
        new_pain = new_state.painscore

        if new_pain < best_pain
          puts "  Better schedule found: previous=#{best_pain} better=#{new_pain}" if @debug
          best_state = new_state.dup
          best_pain = new_pain
          reset_tries_counter = 0
          reset_counter = 0
        end

        if @debug
          inputs = {
            total_iter: total_iter,
            reset_counter: reset_counter,
            reset_tries_counter: reset_tries_counter,
            current_pain: current_pain,
            new_pain: new_pain,
            orig_pain: orig_pain,
            best_pain: best_pain
          }
          print_debugging_string(options, inputs)
        end

        if new_pain <= current_pain
          reset_counter = 0 if new_pain < current_pain
          next if new_pain == current_pain && rand > 0.25
          current_state = new_state
          current_pain = new_pain
        end

        next unless reset_counter >= options[:reset_max]
        reset_tries_counter += 1
        break if reset_tries_counter >= options[:reset_try_max]
        diff = options[:reset_try_max] - reset_tries_counter
        puts "  Schedule reset (#{diff} tries left): this=#{current_pain} best=#{best_pain}" if @debug
        current_state = orig_state.dup
        current_pain = current_state.painscore
        current_iter = 0
        reset_counter = 0
      end

      @rotation = best_state
      best_state
    end

    # Call the 'stats' method in ScheduleMaker::Stats with this schedule's settings
    # @return [Hash] Statistics
    def stats
      ScheduleMaker::Stats.stats(self, @start, @rotation.participants)
    end

    # Render ERB for stats
    # @param filename [String] File name of ERB to render
    # @param objectname [Symbol] Object to render
    # @return [String] Rendered ERB content
    def render_erb(filename, objectname, prefix = '')
      obj = nil
      obj = ScheduleMaker::Model::Stats.new(self) if objectname == :stats
      ScheduleMaker::Util.render_erb(filename, obj, prefix)
    end

    # Render schedule as yaml. Convert symbols to keys.
    # @return [Yaml Object] Yaml
    def to_yaml(options = {})
      schedule_out = as_schedule(@start, participants: @rotation.participants).map do |obj|
        hsh = Hash[obj.map { |k, v| [k.to_s, v] }]
        options.fetch(:with_stats, false) ? hsh : hsh.select { |k, _v| %w(start end assignee length).include?(k) }
      end
      schedule_out.to_yaml
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

      if value.is_a?(Hash)
        raise ArgumentError, "Information for #{key} does not contain 'period_length'" unless value.key?('period_length')
        validate_period(key, value['period_length'])
        return true
      end

      raise ArgumentError, "Key #{key} has invalid period length #{value.class}" unless value.is_a?(Fixnum)
      raise ArgumentError, "period length #{value} is not >= 1" if value < 1
      raise ArgumentError, "period length #{value} is not <= 31" if value > 31
      true
    end
  end
end
