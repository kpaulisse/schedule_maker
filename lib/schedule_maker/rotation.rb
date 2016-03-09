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
    attr_reader :period_lcm, :rotation_length, :rotation, :participants, :target_spacing
    attr_reader :prev_rotation, :start, :day_length, :count, :violations, :default_pain_classes

    # Constructor
    #
    # @param participants [Hash<String,Fixnum>] Participant name (key) and shift length (value)
    # @param options
    #   - :count         => [Fixnum] Number of times to repeat the rotation (default = 1)
    #   - :prev_rotation => [Array<Period>] Previous rotation
    #   - :init_sched    => [Array<Period>] Starting point schedule
    #   - :start         => [DateTime] DateTime object representing start date of this period
    #   - :day_length    => [Float] Representing the length of a "day" (1.0 is normal)
    #   - :ruleset       => [Hash<Ruleset>] Class name => Ruleset
    def initialize(participants, options = {})
      raise ArgumentError, 'Participants argument must be a hash' unless participants.is_a?(Hash)
      raise ArgumentError, 'Participants hash cannot be empty' if participants.empty?
      @period_lcm = ScheduleMaker::RotationUtil.participant_lcm(participants)

      @count = options.fetch(:count, 1)
      raise ArgumentError, 'Count must be an integer' unless @count.is_a?(Fixnum)
      raise ArgumentError, 'Count must be >= 1' unless @count >= 1

      @start = options.fetch(:start, ScheduleMaker::Util.midnight_today)
      @participants = ScheduleMaker::RotationUtil.prepare_participants(participants, @start)
      @target_spacing = @participants.keys.size - 1

      @day_length = options.fetch(:day_length, 86400.0)

      init_sched = options.fetch(:init_sched, nil)

      @rotation = ScheduleMaker::RotationUtil.initial_schedule_handler(init_sched, @participants, @count, @start, @day_length)

      @rotation_length = ScheduleMaker::RotationUtil.calculate_rotation_length(@rotation)

      @prev_rotation = ScheduleMaker::RotationUtil.build_prev_rotation_hash(options.fetch(:prev_rotation, []))
      @prev_rotation_save = options.fetch(:prev_rotation, [])

      @pain_classes = options.fetch(:ruleset, ScheduleMaker::Util.load_ruleset('standard-spacing-algorithm'))
      @pain_override = nil
      @violations = {}
    end

    def inspect
      "<ScheduleMaker::Rotation schedule=#{@rotation.inspect}, pain=#{pain}, painscore=#{painscore} >"
    end

    def dup
      options = {
        start: @start,
        day_length: @day_length,
        count: @count,
        prev_rotation: @prev_rotation_save,
        init_sched: @rotation.dup,
        ruleset: @pain_classes
      }
      ScheduleMaker::Rotation.new(@participants, options)
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
      samples_1 = Array (0..@rotation.size - 1).to_a.sample(26)
      old_score = painscore
      until samples_1.empty?
        index_1 = samples_1.shift
        samples_2 = Array (0..@rotation.size - 1).to_a.shuffle
        until samples_2.empty?
          trial = dup
          index_2 = samples_2.shift
          if !samples_2.empty? && rand > 0.9
            index_3 = samples_2.shift
            next unless swap_legal?(index_1, index_2)
            next unless swap_legal?(index_2, index_3)
            next unless swap_legal?(index_3, index_1)
            trial.swap3(index_1, index_2, index_3)
          else
            next unless swap_legal?(index_1, index_2)
            trial.swap(index_1, index_2)
          end

          new_score = trial.painscore
          if new_score < old_score
            @rotation = trial.rotation
            old_score = new_score
          end
          if new_score > old_score && ((new_score - old_score) * 1.0 / (1.0 * old_score)) < 0.20 && rand > 0.95
            @rotation = trial.rotation
            old_score = new_score
          end
        end
      end
      self
    end

    # Get the "pain" array
    def pain(classes = @pain_classes)
      return @pain_override unless @pain_override.nil? # For testing mostly
      result = {}
      classes.each do |class_name, obj|
        next if class_name =~ /::Hash$/
        x_pain = obj.pain(self)
        x_pain.each do |key, val|
          result[key] ||= { pain: false, score: 0 }
          result[key][:score] += val[:score] if val.key?(:score)
          result[key][:pain] = true if val.key?(:pain) && val[:pain]
        end
      end
      result
    end

    # Test if rotation is valid
    def valid?(_options = {}, classes = @pain_classes)
      classes.each do |class_name, obj|
        next if class_name =~ /::Hash$/
        raise "Invalid object for '#{class_name}' => #{obj.inspect}" if obj.is_a?(Hash)
        puts "About to validate on #{class_name} for #{obj}"
        return false unless obj.valid?(self)
      end
      true
    end

    # Set violations
    def set_violations(source_class, violations)
      @violations[source_class] = violations
    end

    # Calculates the "pain score" of this rotation
    # @param classes [Hash<Class, Float>] Methods used to calculate pain, with weighting
    # @param options [Hash] Options
    # @param pain [Hash] Use this pain hash instead of re-calculating
    # @return [Fixnum] Calculated pain score
    def painscore(classes = @pain_classes, _options = {}, pain_in = nil)
      x_pain = pain_in.nil? ? pain(classes) : pain_in
      result = 0
      pain_multiplier = 0
      x_pain.values.each do |val|
        result += val[:score]**2
        pain_multiplier = 1 if val[:pain]
      end
      (result * pain_multiplier).to_i
    end

    # Swap two elements in the schedule array
    def swap(index_1, index_2)
      @rotation[index_1], @rotation[index_2] = @rotation[index_2], @rotation[index_1]
    end

    # Swap two elements in the schedule array
    def swap3(index_1, index_2, index_3)
      @rotation[index_1], @rotation[index_2], @rotation[index_3] = @rotation[index_2], @rotation[index_3], @rotation[index_1]
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

    # Override a participant's timezone - FOR USE IN SPEC TESTING ONLY
    def override_participant_timezone_from_a_spec_test_only(key, timezone)
      raise "Participant '#{key}' is not defined here" unless @participants.key?(key)
      @participants[key][:timezone] = timezone
    end

    # Override a participant's start date - FOR USE IN SPEC TESTING ONLY
    def override_participant_start_date_from_a_spec_test_only(key, start_date)
      raise "Participant '#{key}' is not defined here" unless @participants.key?(key)
      @participants[key][:start] = ScheduleMaker::Util.dateparse(start_date)
    end

    # Override pain array - FOR USE IN SPEC TESTING ONLY
    def override_pain_from_a_spec_test_only(pain)
      @pain_override = pain
    end
  end
end
